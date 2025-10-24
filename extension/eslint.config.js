import antfu from "@antfu/eslint-config"

export default antfu({
  vue: true,
  typescript: true,
}, {
  rules: {
    "style/quotes": ["error", "double"],
    "vue/html-self-closing": "off",
  },
})
