# == Schema Information
#
# Table name: permissions
#
#  id               :integer          not null, primary key
#  user_id          :integer
#  permissible_id   :integer
#  ref_role_slug    :string(255)
#  status           :string(255)
#  created_by       :integer
#  updated_by       :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  is_hidden        :boolean          default(FALSE)
#  permissible_type :string(255)
#  stream_id        :integer
#  stream_url       :text(65535)
#  bio              :text(65535)
#  meta_description :text(65535)
#

class Permission < ApplicationRecord
    #CONSTANTS
    REF_DEFAULT_ROLES = [['Writer', 'writer'], ["Editor", "editor"]]
    REF_ROLES = [["Editor", "editor"], ['Writer', 'writer'], ['Contributor', 'contributor']]
    #CUSTOM TABLES
    #GEMS
    #CONCERNS
    include Propagatable
    include AssociableBy
    #ASSOCIATIONS
    belongs_to :user
    validates :permissible_type, presence: true
    validates :permissible_id, presence: true
    belongs_to :permissible, polymorphic: true
    belongs_to :permission_role, foreign_key: 'ref_role_slug', primary_key: 'slug'
    has_one :stream, primary_key: "stream_id", foreign_key: "id"

    #ACCESSORS
    attr_accessor :redirect_url, :sites,:site_ref_role_slug
    #VALIDATIONS
    validates :user_id, presence: true
    validates :ref_role_slug, presence: true
    validate  :is_unique_row?, on: :create

    #CALLBACKS
    before_create :before_create_set
    after_save :after_save_set

    #SCOPE
    scope :not_hidden, -> { where(is_hidden: false) }
    scope :hidden, -> { where(is_hidden: true) }
    scope :account_permissions, -> { where(permissible_type: "Account") }
    scope :site_permissions, -> { where(permissible_type: "Site") }
    #OTHER

    def view_casts
        if self.permissible_type == "Site"
            ViewCast.where(template_card_id: TemplateCard.where(name: "toStory").pluck(:id)).where(byline_id: self.id)
        else
            ViewCast.none
        end
    end

    def username
        self.user.name
    end

    #PRIVATE
    private

    def is_unique_row?
        if Permission.where(permissible_type: self.permissible_type, permissible_id: self.permissible_id, user_id: self.user_id, status: "Active").first.present?
            errors.add(:user_id, "already invited.")
            return false
        end
    end

    def before_create_set
        self.status = "Active"
        true
    end

    def after_create_set
        if s.permissible_type == "Site"
            s = Stream.create!({
                is_automated_stream: true,
                col_name: "Permission",
                col_id: self.id,
                account_id: self.account_id,
                site_id: self.permissible_id,
                title: "#{self.user.name}",
                description: "#{self.user.name} stream",
                limit: 50
            })
            self.update_columns(stream_url: "#{s.site.cdn_endpoint}/#{s.cdn_key}", stream_id: s.id)
        end
    end

    def after_save_set
        if self.sites and self.sites.count > 0
            self.sites = self.sites.reject(&:empty?)
            self.sites.each do |s|
                user.create_permission("Site", s, self.site_ref_role_slug)
            end
        end
    end


end
