class ViewCastsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_view_cast, only: [:show, :edit, :destroy, :recreate, :update]
    before_action :sudo_can_see_all_view_casts, only: [:show, :edit, :update]

    def new
        @new_image = Image.new
        @intersections = [""] + @site.ref_categories.where(genre: 'intersection').pluck(:name)
        @subintersections = [""] + @site.ref_categories.where(genre: 'sub intersection').pluck(:name)
    end

    def index
      if @permission_role.can_see_all_view_casts
        z = @folder.view_casts.where.not(template_card_id: TemplateCard.to_story_cards_ids).where(is_autogenerated: false).page(params[:page]).per(15)
      else
        z = current_user.view_casts(@folder).where(is_autogenerated: false).page(params[:page]).per(15)
      end
      @card_types = TemplateCard.where(id: z.pluck(:template_card_id).uniq)
      @q = z.search(params[:q])
      @view_casts = @q.result.page(params[:page]).per(15)
      @is_viewcasts_present = @view_casts.count != 0
      
    end

    def show
        @folders_dropdown = @site.folders.active
        if (Time.now - @view_cast.updated_at) > 5.minute and (@view_cast.is_invalidating)
            @view_cast.update_column(:is_invalidating, false)
        end
        @view_cast_seo_blockquote = @view_cast.seo_blockquote.to_s.split('`').join('\`')
        @view_casts_count = @folder.view_casts.count
        @streams_count = @folder.streams.count
        @view_cast.collaborator_lists = @view_cast.users.pluck(:id)
        
    end

    def edit
        if @view_cast.is_disabled_for_edit
            redirect_to [@site, @folder, @view_cast], alert: "Permission Denied."
        end
        @new_image = Image.new
        @intersections = [""] + @site.ref_categories.where(genre: 'intersection').pluck(:name)
        @subintersections = [""] + @site.ref_categories.where(genre: 'sub intersection').pluck(:name)
    end

    def update
        v_c_params = view_cast_params
        v_c_params["stop_callback"] = true
        if @view_cast.update(v_c_params)
            track_activity(@view_cast)
            if @view_cast.redirect_url.present?
                redirect_to @view_cast.redirect_url, notice: t('us')
            else
                redirect_to site_folder_view_cast_path(@site, @view_cast.folder, @view_cast), notice: t('us')
            end
        else
            render :show
        end

    end

    def destroy
        @view_cast.updator = current_user
        @view_cast.folder = @site.folders.find_by(name: "Trash")
        if @view_cast.save
            StreamEntity.view_casts.where(entity_value: @view_cast.id.to_s).each do |d|
                d.destroy
                StreamPublisher.perform_async(d.stream_id)
            end
            redirect_to site_folder_view_casts_path(@site, @folder), notice: "Card was deleted successfully"
        else
            redirect_to site_folder_view_cast_path(@site, @folder, @view_cast), alert: "Card could not be deleted"
        end
    end

    def set_view_cast
        @view_cast = @site.view_casts.friendly.find(params[:id])
    end

    private

    def view_cast_params
        params.require(:view_cast).permit(:folder_id, :default_view, :redirect_url, collaborator_lists: [])
    end

end
