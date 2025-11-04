namespace :search do
  desc "Rebuild search_projection for Link"
  task rebuild_link: :environment do
    Link.find_each(batch_size: 100) { |r| r.rebuild_search_projection }
  end
end
