class PermissionInvitesController < ApplicationController

  before_action :authenticate_user!#, :sudo_role_can_account_settings
  before_action :set_permission_invite, only: [:show, :edit, :update, :destroy]

  def index
    @permissions = @site.permissions.not_hidden.includes(:user).page params[:page]
    @permission_invite = PermissionInvite.new
    @permission_invites = @site.permission_invites
    @people_count = @site.permissions.not_hidden.count
    @pending_invites_count = @site.permission_invites.count
    @permission_invites = @site.permission_invites
    @permission_roles = PermissionRole.where.not(slug: "owner").pluck(:name, :slug)
  end

  def create
    @permission_invite = PermissionInvite.new(permission_invite_params)
    per = UserEmail.find_by(email: @permission_invite.email)
    user = per.present? ? per.user : nil
    if user.present?
      user.create_permission(@account.id, @permission_invite.ref_role_slug)
      redirect_to account_permissions_url(@account), notice: t("permission_invite.add")
    else
      if @permission_invite.save
        PermissionInvites.invite(current_user, @account, @permission_invite.email).deliver
        redirect_to account_permissions_url(@account), notice: t("permission_invite.invite")
      else
        @permissions = @account.permissions.includes(:user).page params[:page]
        @permission_invites = @account.permission_invites
        @people_count = @account.users.count
        @pending_invites_count = @account.permission_invites.count
        @permission_invites = @account.permission_invites
        @show_modal = true
        render "permission_invites/index"
      end
    end
  end

  def destroy
    with_only_account = @permission_invite.site_id.blank?
    @permission_invite.destroy
    if with_only_account
      redirect_to edit_account_url(@account), notice: t("permission_invite.removed")
    else
      redirect_to account_permissions_url(@account), notice: t("permission_invite.removed")
    end
  end

  private

    def set_permission_invite
      @permission_invite = PermissionInvite.find(params[:id])
    end

    def permission_invite_params
      params.require(:permission_invite).permit(:email, :ref_role_slug, :created_by, :updated_by, :permissible_type, :permissible_id)
    end
end
