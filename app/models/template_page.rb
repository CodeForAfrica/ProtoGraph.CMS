# == Schema Information
#
# Table name: template_pages
#
#  id                  :bigint(8)        not null, primary key
#  name                :string(255)
#  description         :text
#  global_slug         :text
#  is_current_version  :boolean
#  slug                :string(255)
#  version_series      :string(255)
#  previous_version_id :bigint(8)
#  version_genre       :string(255)
#  version             :string(255)
#  change_log          :text
#  status              :string(255)
#  publish_count       :bigint(8)
#  is_public           :boolean
#  git_url             :string(255)
#  git_branch          :string(255)
#  git_repo_name       :string(255)
#  s3_identifier       :string(255)
#  created_by          :bigint(8)
#  updated_by          :bigint(8)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class TemplatePage < ApplicationRecord

    #CONSTANTS
    CDN_BASE_URL = "#{ENV['AWS_S3_ENDPOINT']}"

    #CUSTOM TABLES
    #GEMS
    require 'version'
    extend FriendlyId
    friendly_id :slug_candidates, use: :slugged
    #CONCERNS
    include AssociableBySi
    include Versionable
    #ASSOCIATIONS
    has_many :pages

    #ACCESSORS
    #VALIDATIONS
    validates :name, presence: true

    #CALLBACKS
    before_create :before_create_set

    #SCOPE
    #OTHER

    def is_article_page?
        self.name == "article"
    end

    def slug_candidates
        ["#{self.name}-#{self.version.to_s}"]
    end

    private

    def should_generate_new_friendly_id?
        slug.blank? || name_changed?
    end

     def before_create_set
        self.publish_count = 0
        self.global_slug = self.name.parameterize
        self.s3_identifier = SecureRandom.hex(6) if self.s3_identifier.blank?
        true
    end

end
