#!/usr/bin/env node

import babel from '@babel/core'
import esbuild from 'esbuild'
import coffeeScriptPlugin from 'esbuild-coffeescript'
import fsPromises from 'fs/promises'

const outdir = 'app/assets/builds'
const outfileEsbuild = 'application_es6.js'
const outfileEsbuildPath = `${outdir}/${outfileEsbuild}`
const outfileBabel = 'application.js'
const outfileBabelPath = `${outdir}/${outfileBabel}`

const babelOnEnd = {
  name: 'babelOnEnd',
  setup (build) {
    build.onEnd(async () => {
      const inputSourceMapString = await fsPromises.readFile(`${outfileEsbuildPath}.map`)
      const options = {
        presets: [
          ['@babel/preset-env']
        ],
        inputSourceMap: JSON.parse(inputSourceMapString),
        sourceMaps: true
      }
      const outEsbuild = await fsPromises.readFile(outfileEsbuildPath)
      const result = await babel.transformAsync(outEsbuild, options)

      return Promise.all([
        fsPromises.writeFile(outfileBabelPath, `${result.code}\n//# sourceMappingURL=${outfileBabel}.map`),
        fsPromises.writeFile(`${outfileBabelPath}.map`, JSON.stringify(result.map))
      ])
    })
  }
}

esbuild.build({
  bundle: true,
  entryPoints: ['app/javascript/application.coffee'],
  nodePaths: ['app/javascript'],
  outfile: outfileEsbuildPath,
  plugins: [coffeeScriptPlugin({ bare: true }), babelOnEnd],
  resolveExtensions: ['.coffee', '.js'],
  sourcemap: true,
  watch: process.argv[2] === '--watch'
})
