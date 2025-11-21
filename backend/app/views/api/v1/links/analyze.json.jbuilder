# API response for link analysis
# Returns AI-generated suggestions for tags and notes
#
# Response format matches spec.md#3.3:
# {
#   data: {
#     suggested_note: String,
#     suggested_tags: [{name: String, exists: Boolean}]
#   }
# }
json.data do
  json.suggested_note @suggested_note
  json.suggested_tags @suggested_tags do |tag|
    json.name tag[:name]
    json.exists tag[:exists]
  end
end
