module.exports = {
  test: /\.coffee(\.erb)?$/,
  use: [{
    loader: 'coffee-loader',
    options: {
      transpile: {
        presets: ['@babel/env'],
      }
    },
  }]
}
