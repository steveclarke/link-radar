json.extract! link, :id, :url, :title, :note

json.tags do
  json.array! link.tags do |tag|
    json.extract! tag, :id, :name, :slug
  end
end
