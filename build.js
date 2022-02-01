#!/usr/bin/env node

import coffeeScriptPlugin from 'esbuild-coffeescript'
import esbuild from 'esbuild'

esbuild.build({
  bundle: true,
  entryPoints: ['app/javascript/application.coffee'],
  nodePaths: ['app/javascript'],
  outdir: 'app/assets/builds',
  plugins: [coffeeScriptPlugin({ bare: true })],
  resolveExtensions: ['.coffee', '.js'],
  sourcemap: true,
  watch: process.argv[2] === '--watch'
})
