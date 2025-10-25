json.extract! link,
  :id,
  :url,
  :submitted_url,
  :title,
  :note,
  :image_url,
  :content_text,
  :fetch_state,
  :fetch_error,
  :fetched_at,
  :metadata,
  :created_at,
  :updated_at

json.tags do
  json.array! link.tags do |tag|
    json.extract! tag, :id, :name, :slug
  end
end
