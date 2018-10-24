namespace :spotlight do
    task load_metoo_cards: :environment do
        project_site = Rails.env.development? ? Site.friendly.find('pyktest') : Site.friendly.find('projects')
        current_user = User.find(2)
        template_card = TemplateCard.where(name: 'ToRecordMeToo').first
        all_crimes = JSON.parse(File.read("#{Rails.root.to_s}/ref/spotlight/metoo.json"))
        folder = Rails.env.development? ? Folder.friendly.find('metoo') : Folder.friendly.find('database')
        all_crimes.each do |d|
            name = "#{d['created_at']} - #{d['accused_name']} - #{d['complainant_name']}"
            data = {}
            data["data"] = d
            data["data"]['source_url'] = d['source_url']
            data["data"]['text'] = d['text']
            data["data"]['created_at'] = DateTime.strptime(d['created_at'], '%d/%m/%Y %H:%M:%S')
            data['data']['source_platform'] = d['source_platform']
            data['data']['accused_name'] = d['accused_name']
            data['data']['accused_org'] = d['accused_org']
            data['data']['accused_handle'] = d['accused_handle']
            data['data']['complainant_name'] = d['complainant_name']
            data['data']['complainant_handle'] = d['complainant_handle']
            data['data']['industry'] = d['industry']
            data['data']['context'] = d['context']
            data['data']['nautre'] = d['nature']
            payload = {}
            payload["payload"] = data.to_json
            payload["source"]  = "form"
            card = ViewCast.create({
                site_id: project_site.id,
                name: name,
                seo_blockquote: "",
                folder_id: folder.id,
                ref_category_vertical_id: folder.ref_category_vertical_id,
                template_card_id: template_card.id,
                template_datum_id:  template_card.template_datum_id,
                created_by: current_user.id,
                updated_by: current_user.id,
                optionalconfigjson: {},
                data_json: data
            })

            payload["api_slug"] = card.datacast_identifier
            payload["schema_url"] = card.template_datum.schema_json
            payload["bucket_name"] = project_site.cdn_bucket

            r = Api::ProtoGraph::Datacast.create(payload)
            if r.has_key?("errorMessage")
                card.destroy
                puts r['errorMessage']
                puts "================="
            else
                puts "Saved Profile Card"
            end
        end
    end
end