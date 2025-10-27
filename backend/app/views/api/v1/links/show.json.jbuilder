json.data do
  json.link do
    json.partial! "api/v1/links/link", link: @link
  end
end
