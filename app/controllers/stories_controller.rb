require 'json'
require 'net/http'
require 'open-uri'

class StoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_page, only: [:edit_write, :edit_assemble, :edit_distribute, :edit_ads]
  before_action :sudo_can_see_all_pages, only: [:edit_write, :edit_write, :edit_assemble, :edit_distribute, :edit_ads]

  def index
    if params[:page].present? and params[:page].class != String
      p_params = page_params
      @page = Page.new(p_params)
      if p_params["ref_category_series_id"].blank?
        redirect_to site_stories_path(@site, folder_id: @page.folder_id), alert: 'You must associate a vertical with workspace'
      else
        if p_params.has_key?('cover_image_attributes') and !p_params['cover_image_attributes'].has_key?("image")
          p_params.delete('cover_image_attributes')
        end
        @page.headline = @page.one_line_concept
        @page.english_headline = @page.one_line_concept unless @site.is_english
        @page.created_by = current_user.id
        @page.updated_by = current_user.id
        @page.collaborator_lists = ["#{current_user.id}"] if ["contributor", "writer"].include?(@permission_role.slug)
        if @page.save
          redirect_to site_stories_path(@site, folder_id: @page.folder_id), notice: 'Page was successfully created.'
        else
          flash.now.alert = @page.errors.full_messages
          redirect_to site_stories_path(@site, folder_id: @page.folder_id), alert: 'Error creating page'
        end
      end
    else
      if @permission_role.can_see_all_pages
        z = @folder.pages.where(template_page_id: TemplatePage.where.not(name: "Homepage: Vertical").pluck(:id).uniq)
      else
        z = current_user.pages(@folder).where(template_page_id: TemplatePage.not(name: "Homepage: Vertical").pluck(:id).uniq)
      end
      @bylines = Permission.where(id: z.pluck(:byline_id).uniq).order(:name)
      @q = z.search(params[:q])
      @pages = @q.result.page(params[:page]).per(15)
      @page = Page.new
      @ref_intersection = RefCategory.where(site_id: @site.id, genre: "intersection", is_disabled: [false, nil]).order(:name).map {|r| ["#{r.name}", r.id]}
      @ref_intersections = RefCategory.where(site_id: @site.id, genre: "intersection", is_disabled: [false, nil]).order(:name)
      @ref_sub_intersection = RefCategory.where(site_id: @site.id, genre: "sub intersection", is_disabled: [false, nil]).order(:name).map {|r| ["#{r.name}", r.id]}
      @ref_sub_intersections = RefCategory.where(site_id: @site.id, genre: "sub intersection", is_disabled: [false, nil]).order(:name)
      @article = TemplatePage.where(name: "article").first
      @article_or_compendium = TemplatePage.where(name: ['article', 'compendium']).pluck(:name, :id).map{|d| [d[0].titleize, d[1]]}
    end
  end

  def edit_assemble
    @view_cast = @page.view_cast if @page.view_cast_id.present?
    @page_streams = @page.page_streams
    @page.publish = @page.status == 'published'
    @is_article_page = @page.template_page.name == "article"
    @page_stream_narrative = @page.streams.where(title: "#{@page.id.to_s}_Story_Narrative").first
    @page_stream_related = @page.streams.where(title: "#{@page.id.to_s}_Story_Related").first
    @page_stream_related7c = @page_stream_related.page_streams.first
    @page_stream_narrative7c = @page_stream_narrative.page_streams.first
    exclude_view_casts = StreamEntity.view_casts.where(stream_id: [@page_stream_narrative.id, @page_stream_related.id]).pluck(:entity_value)
    @all_cards = @site.view_casts.where.not(id: exclude_view_casts).where(is_autogenerated: false, template_card_id: TemplateCard.where.not(name: ['toParagraph', "Oxfam IRBF: toCompanyProfile", "Oxfam IRBF: toQuestion", "Oxfam IRBF: toSurveyScores","toData: Rating with drill down", "toData: IRBF Grid", "toData: IRBF Tooltip"])).where(folder_id: @site.folders.active.where(ref_category_vertical_id: @page.series.id).pluck(:id)).order([updated_at: :desc, created_at: :desc])
    @all_cards += @site.view_casts.where.not(id: exclude_view_casts).where(template_card_id: TemplateCard.where(name: "toStory")).where(is_autogenerated: true).where(folder_id: @site.folders.active.where(ref_category_vertical_id: @page.series.id).pluck(:id)).order([updated_at: :desc, created_at: :desc])
    if @page.template_page.name == "Homepage: Vertical"
      title = "#{@page.id.to_s}_Section_16c_Hero"
    elsif @page.template_page.name == "article" or @page.template_page.name == "compendium"
      title = "#{@page.id.to_s}_Story_16c_Hero"
    else
      title = "#{@page.id.to_s}_Data_16c_Hero"
    end
    @page_stream_16 = @page.streams.where(title: title).first
    @page_streamH16 = @page.page_streams.where(name_of_stream: "Hero").first
    @stream_entity = StreamEntity.new
  end

  def edit_write
    #- Seamless writing experience that gets converted into many Compose Cards
    #- Rao's app / Medium / Google Doc
    #@ref_intersection = RefCategory.where(site_id: @site.id, genre: "intersection", is_disabled: [false, nil]).order(:name).map {|r| ["#{r.name}", r.id]}
    #@ref_sub_intersection = RefCategory.where(site_id: @site.id, genre: "sub intersection", is_disabled: [false, nil]).order(:name).map {|r| ["#{r.name}", r.id]}
    @template_cards = @site.template_cards.where(is_current_version: true)

  end

  def edit_distribute
    #  cover_image_url_facebook         :text(65535)
    #  cover_image_url_square           :text(65535)
    # - Tags []
    # - Related to Geography?
    #     > Country
    #     > State
    #     > District
    #     > Location
    @cover_image_alignment = [["Horizontal", "horizontal"], ["Vertical", "vertical"]]
    @ref_category_intersection = @site.ref_categories.where(genre: "intersection").map {|i| [i.name, i.id]}
    @ref_category_sub_intersection = @site.ref_categories.where(genre: "sub intersection").map {|i| [i.name, i.id]}
    @image = @page.cover_image
    if @image.blank?
        @page.build_cover_image
    end
    #  cover_image_id_7_column          :integer
    #  cover_image_id_4_column
    #  cover_image_id_3_column
    #  cover_image_id_2_column
    #  cover_image_credit


  end

  def edit_ads
    @ad_integrations = @page.ad_integrations
    @page_streams = @page.page_streams
    @ad_integration = AdIntegration.new
  end

  def import_story
    p_params = page_params
    @page = Page.new(p_params)
    @page.created_by = current_user.id
    @page.updated_by = current_user.id
    @page.headline = "Headline"
    # @page.html_key = "default_html_key"
    @page.published_at = DateTime.now
    if @page.save!
      redirect_to site_stories_path(@site, folder_id: @page.folder_id), notice: "Story will be imported shortly"
    else
      redirect_to site_stories_path(@site, folder_id: @page.folder_id), alert: "Error importing story"
    end
  end


  private

    def set_page
      @page = Page.friendly.find(params[:id])
    end

    def page_params
      params.require(:page).permit(:id, :site_id, :folder_id, :import_url, :headline, :meta_keywords, :meta_description, :summary, :template_page_id, :byline_id, :one_line_concept,
                                   :cover_image_url, :cover_image_url_7_column, :cover_image_url_facebook, :cover_image_url_square, :cover_image_alignment, :content,
                                   :is_sponsored, :is_interactive, :has_data, :has_image_other_than_cover, :has_audio, :has_video, :status, :published_at, :url,
                                   :ref_category_series_id, :ref_category_intersection_id, :ref_category_sub_intersection_id, :view_cast_id, :page_object_url, :created_by,:html_key,
                                   :updated_by, :english_headline, :due, :description, :cover_image_id_4_column, :cover_image_id_3_column, :cover_image_id_2_column, :cover_image_credit, :share_text_facebook,
                                     :share_text_twitter, :publish, :prepare_cards_for_assembling, :format, :importance,:external_identifier, collaborator_lists: [], cover_image_attributes: [:image, :site_id,:is_cover, :created_by,
                                     :updated_by])
    end
end
