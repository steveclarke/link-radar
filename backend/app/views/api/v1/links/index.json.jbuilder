json.meta do
  json.partial! "api/v1/shared/pagination", pagination: @pagination
end

json.data do
  json.links @links, partial: "api/v1/links/link", as: :link
end
