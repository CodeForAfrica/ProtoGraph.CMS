# == Schema Information
#
# Table name: ref_categories
#
#  id          :integer          not null, primary key
#  site_id     :integer
#  category    :string(255)
#  name        :string(255)
#  stream_url  :text(65535)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  stream_id   :integer
#  is_disabled :boolean
#  created_by  :integer
#  updated_by  :integer
#

class RefCategory < ApplicationRecord
    #CONSTANTS
    #CUSTOM TABLES
    #GEMS
    #ASSOCIATIONS
    belongs_to :site
    has_one :stream, foreign_key: 'id', primary_key: 'stream_id'
    belongs_to :creator, class_name: "User", foreign_key: "created_by"
    belongs_to :updator, class_name: "User", foreign_key: "updated_by"

    #ACCESSORS
    #VALIDATIONS
    validates :name, presence: true, uniqueness: {scope: :site}
    validates :category, inclusion: {in: ["intersection", "sub intersection", "series"]}

    #CALLBACKS
    after_create :after_create_set
    #SCOPE
    #OTHER
    #PRIVATE

    def view_casts
        ViewCast.where("#{category}": self.name)
    end

    private

    def after_create_set
        s = Stream.create!({
            is_automated_stream: true,
            col_name: "RefCategory",
            col_id: self.id,
            account_id: self.site.account_id,
            title: self.name,
            description: "#{self.name} stream",
            limit: 50
        })

        Thread.new do
            s.publish_cards
            ActiveRecord::Base.connection.close
        end

        self.update_columns(stream_url: "#{s.stream.cdn_endpoint}/#{s.cdn_key}", stream_id: s.id)
    end
end
