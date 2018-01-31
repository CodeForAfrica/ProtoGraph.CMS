# == Schema Information
#
# Table name: pages
#
#  id                               :integer          not null, primary key
#  account_id                       :integer
#  site_id                          :integer
#  folder_id                        :integer
#  headline                         :string(255)
#  meta_keywords                    :string(255)
#  meta_description                 :text(65535)
#  summary                          :text(65535)
#  byline                           :string(255)
#  byline_stream                    :string(255)
#  cover_image_url                  :text(65535)
#  cover_image_url_7_column         :text(65535)
#  cover_image_url_facebook         :text(65535)
#  cover_image_url_square           :text(65535)
#  cover_image_alignment            :string(255)
#  is_sponsored                     :boolean
#  is_interactive                   :boolean
#  has_data                         :boolean
#  has_image_other_than_cover       :boolean
#  has_audio                        :boolean
#  has_video                        :boolean
#  is_published                     :boolean
#  published_at                     :datetime
#  url                              :text(65535)
#  ref_category_series_id           :integer
#  ref_category_intersection_id     :integer
#  ref_category_sub_intersection_id :integer
#  view_cast_id                     :integer
#  page_object_url                  :text(65535)
#  created_by                       :integer
#  updated_by                       :integer
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  datacast_identifier              :string(255)
#  is_open                          :boolean
#  template_page_id                 :integer
#  slug                             :string(255)
#  english_headline                 :string(255)
#

class Page < ApplicationRecord

  #CONSTANTS
  #CUSTOM TABLES
  #GEMS
  extend FriendlyId
  friendly_id :english_headline, use: :slugged

  #ASSOCIATIONS
  belongs_to :account
  belongs_to :site
  belongs_to :folder, optional: true
  belongs_to :series, class_name: "RefCategory", foreign_key: :ref_category_series_id, optional: true
  belongs_to :intersection, class_name: "RefCategory", foreign_key: :ref_category_intersection_id, optional: true
  belongs_to :sub_intersection, class_name: "RefCategory", foreign_key: :ref_category_sub_intersection_id, optional: true
  belongs_to :view_cast, optional: true
  belongs_to :creator, class_name: "User", foreign_key: "created_by"
  belongs_to :updator, class_name: "User", foreign_key: "updated_by"
  belongs_to :template_page
  has_many :page_streams
  has_many :streams, through: :page_streams
  has_many :permissions, ->{where(status: "Active", permissible_type: 'Page')}, foreign_key: "permissible_id", dependent: :destroy
  has_many :users, through: :permissions

  #ACCESSORS
  attr_accessor :collaborator_lists
  #VALIDATIONS
  validates :headline, presence: true, length: { in: 50..90 }
  validates :summary, length: { in: 50..220 }, allow_blank: true

  #CALLBACKS
  before_create :before_create_set
  before_save :before_save_set

  after_create :create_page_streams
  after_create :create_story_card
  after_create :push_json_to_s3

  after_update :create_story_card
  after_update :push_json_to_s3
  after_save :after_save_set

  # Slug

  def html_key
    "#{self.site.slug}/#{self.series.slug}/#{self.slug}-#{self.id}"
    # Change during Multi Domain functionality
  end

  def html_url
    "#{self.site.cdn_endpoint}/#{html_key}.html"
    # Change during Multi Domain functionality
  end

  #SCOPE
  #OTHER
  def push_json_to_s3
    site = self.site

    streams = self.page_streams.includes(:stream).map do |e|
      k = e.stream.as_json
      h = {}
      h['id'] = k['id']
      h['title'] = k['title']
      h['datacast_identifier'] = k['datacast_identifier']
      h['url'] = "#{self.site.cdn_endpoint}/#{k['datacast_identifier']}/index.json"
      h['name_of_stream'] = e.name_of_stream
      h
    end

    page = self.as_json(methods: [:html_key])
    page['layout'] = self.template_page.as_json

    json = {
      "site_attributes": {
        "dis_qus_integration": "",
        "youtube_url": site.youtube_url,
        "instagram_url": site.instagram_url,
        "twitter_url": site.twitter_url,
        "facebook_url": site.facebook_url,
        "house_colour": site.house_colour,
        "reverse_house_colour": site.reverse_house_colour,
        "font_colour": site.font_colour,
        "reverse_font_colour": site.reverse_font_colour,
        "logo_url": site.logo_image.present? ? site.logo_image.thumbnail_url : "",
        "favicon_url": site.favicon.present? ? site.favicon.thumbnail_url : "",
        "ga_code": site.g_a_tracking_id,
        "story_card_style": site.story_card_style
      },
      "streams": streams,
      "page": page,
      "ref_category_object": {"name": "#{self.series.name}", "name_html": "#{self.series.name_html}"},
      "vertical_header_json_url": "#{self.series.vertical_header_url}",
      "homepage_header_json_url": "#{self.site.homepage_header_url}",
      "site_header_json_url": "#{self.site.header_json_url}"
    }
    key = "#{self.datacast_identifier}/page.json"
    encoded_file = Base64.encode64(json.to_json)
    content_type = "application/json"
    resp = Api::ProtoGraph::Utility.upload_to_cdn(encoded_file, key, content_type)
    self.update_column(:page_object_url, "#{self.site.cdn_endpoint}/#{key}")
    if !Rails.env.development?
      # PagesWorker.perform_async(self.id)
      response = Api::ProtoGraph::Page.create_or_update_page(self.datacast_identifier, self.template_page.s3_identifier)
      puts "=====> #{response}"
      Api::ProtoGraph::CloudFront.invalidate(nil, ["/#{CGI.escape(self.html_key)}"], 1)
    end
    if self.site.cdn_id != ENV['AWS_CDN_ID']
      Api::ProtoGraph::CloudFront.invalidate(self.site, ["/#{CGI.escape(key)}"], 1)
    end
    Api::ProtoGraph::CloudFront.invalidate(nil, ["/#{CGI.escape(key)}"], 1)
    true
  end
  #PRIVATE
  private

  def before_create_set
    self.datacast_identifier = SecureRandom.hex(12)   if self.datacast_identifier.blank?
    self.is_interactive = false                       if self.is_interactive.blank?
    self.has_data = false                             if self.has_data.blank?
    self.has_image_other_than_cover = false           if self.has_image_other_than_cover.blank?
    self.has_audio = false                            if self.has_audio.blank?
    self.has_video = false                            if self.has_video.blank?
    self.is_sponsored = false                         if self.is_sponsored.blank?
    self.is_published = false                         if self.is_published.blank?
    self.cover_image_alignment = "horizontal"         if self.cover_image_alignment.blank?
    self.url = "#{self.site.cdn_endpoint}/#{self.datacast_identifier}/index.html" if self.url.blank?
    true
  end

  def before_save_set
    if self.has_data == true or self.has_image_other_than_cover == true or self.has_audio == true or self.has_video == true
      self.is_interactive = true
    end
    self.english_headline = self.headline if self.site.is_english
    true
  end

  def create_page_streams
    streams = []
    case self.template_page.name
    when 'Homepage: Vertical'
      streams = [["Section_16c_Hero", "Hero"], ["Section_7c", "Originals"], ["Section_4c", "Digests"], ["Section_3c", "Feed"], ["Section_2c", "Opinions"]]
    when 'article'
      streams = [["Story_Narrative", "#{self.id}_Section_7c"], ["Story_Related", "#{self.id}_Section_7c"]]
    when 'data grid'
      streams = [["Data_Grid", "#{self.id}_Section_data"]]
    end
    streams.each do |s|
      stream = Stream.create!({
        col_name: "Page",
        col_id: self.id,
        account_id: self.account_id,
        site_id: self.site_id,
        folder_id: self.folder_id,
        created_by: self.created_by,
        updated_by: self.updated_by,
        title: "#{self.id}_#{s.first}",
        description: "#{self.id}-#{s.first} stream #{self.summary}"
      })

      page_stream = PageStream.create!({
        page_id: self.id,
        stream_id: stream.id,
        name_of_stream: s.last,
        created_by: self.created_by,
        updated_by: self.updated_by
      })
    end
    true
  end

  def create_story_card
    site = self.site
    self.update_column(:published_at, Time.now)
    if self.is_published == true
      if self.view_cast.present?
        view_cast = self.view_cast
        view_cast.update({
          name: self.headline,
          updated_by: self.updated_by,
          seo_blockquote: "<blockquote><h4#>#{self.headline}</h4></blockquote>",
          folder_id: self.folder_id
        })
      else
        view_cast = ViewCast.create({
          name: self.headline,
          site_id: site.id,
          template_card_id: TemplateCard.where(name: 'toStory').first.id,
          template_datum_id: TemplateDatum.where(name: 'toStory').first.id,
          optionalConfigJSON: {
            "house_color": site.house_colour,
            "inverse_house_color": site.reverse_house_colour,
            "house_font_color": site.font_colour,
            "inverse_house_font_color": site.reverse_font_colour,
          },
          created_by: self.created_by,
          updated_by: self.updated_by,
          seo_blockquote: "<blockquote><h4#>#{self.headline}</h4></blockquote>",
          folder_id: self.folder_id,
          default_view: "title_text",
          account_id: self.account_id
        })
      end
      payload = {}
      payload["payload"] = create_datacast_json.to_json
      payload["api_slug"] = view_cast.datacast_identifier
      payload["schema_url"] = view_cast.template_datum.schema_json
      payload["source"] = "form"
      if self.view_cast_id.present?
        r = Api::ProtoGraph::Datacast.update(payload)
      else
        r = Api::ProtoGraph::Datacast.create(payload)
        self.update_column(:view_cast_id, view_cast.id)
      end
      if self.account.cdn_id != ENV['AWS_CDN_ID']
        Api::ProtoGraph::CloudFront.invalidate(@account, ["/#{view_cast.datacast_identifier}/data.json","/#{view_cast.datacast_identifier}/view_cast.json"], 2)
      end
      Api::ProtoGraph::CloudFront.invalidate(nil, ["/#{view_cast.datacast_identifier}/*"], 1)
    end
    true
  end

  def create_datacast_json
    data = {"data" => {}}
    data["data"]["url"] = self.url.to_s if self.url.present?
    data["data"]["headline"] = self.headline.to_s if self.headline.present?
    data["data"]["byline"] = self.byline.to_s if self.byline.present?
    data["data"]["publishedat"] = self.published_at.strftime("%Y-%m-%dT%H:%M") if self.published_at.present?
    data["data"]["series"] = self.series.name.to_s if self.series.present? and self.series.name.present?
    data["data"]["genre"] = self.intersection.name.to_s if self.intersection.present? and self.intersection.name.present?
    data["data"]["subgenre"] = self.sub_intersection.name.to_s if self.sub_intersection.present? and self.sub_intersection.name.present?
    data["data"]["iconbgcolor"] = "white"
    data["data"]["hasimage"] = self.has_image_other_than_cover if self.has_image_other_than_cover.present?
    data["data"]["hasvideo"] = self.has_video if self.has_video.present?
    data["data"]["hasdata"] = self.has_data if self.has_data.present?
    data["data"]["interactive"] = self.is_interactive if self.is_interactive.present?
    data["data"]["imageurl"] = self.cover_image_url.to_s if self.cover_image_url.present?
    data["data"]["col7imageurl"] = self.cover_image_url_7_column.to_s if self.cover_image_url_7_column.present?
    data["data"]["focus"] = "h"
    data["data"]["country"] = "India"
    data["data"]["state"] = ""
    data["data"]["city"] = ""
    data["data"]["publishername"] = ""
    data["data"]["sponsored"] = self.is_sponsored.to_s if self.is_sponsored.present?
    data["data"]["domainurl"] = Addressable::URI.parse(self.url.to_s).origin if self.url.present?
    data["data"]["faviconurl"] = site.favicon.present? ? site.favicon.thumbnail_url : "" if self.site.favicon.present?
    data["data"]["publishername"] = Addressable::URI.parse(self.url.to_s).origin if self.url.present?
    data["data"]["imageurl"] = self.cover_image_url.to_s if self.cover_image_url.present?
    data["data"]["col7imageurl"] = self.cover_image_url_7_column.to_s if self.cover_image_url_7_column.present?
    data
  end

  def after_save_set
        if self.collaborator_lists.present?
            self.collaborator_lists = self.collaborator_lists.reject(&:empty?)
            prev_collaborator_ids = self.permissions.pluck(:user_id)
            self.collaborator_lists.each do |c|
                user = User.find(c)
                a = user.create_permission("Page", self.id, "contributor")
            end
            self.permissions.where(permissible_id: (prev_collaborator_ids - self.collaborator_lists.map{|a| a.to_i})).update_all(status: 'Deactivated')
        end
    end

end
