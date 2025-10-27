json.data do
  json.links @links, partial: "api/v1/links/link", as: :link
end
