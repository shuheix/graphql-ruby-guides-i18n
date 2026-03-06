# graphql-ruby-guides-i18n

Unofficial translations of the [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) guides. This project is not affiliated with or endorsed by the graphql-ruby project.

## Languages

- English (upstream mirror)
- Japanese

## Upstream Sync

The English guides are synced from upstream using:

```sh
ruby scripts/sync_upstream.rb
```

This pulls the latest guides from [rmosolgo/graphql-ruby](https://github.com/rmosolgo/graphql-ruby) and converts them to [Starlight](https://starlight.astro.build/) format.

## Development

```sh
pnpm install
pnpm run dev
```

## License

The original guide content in `src/content/docs/` (excluding `ja/`) is derived from [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) by Robert Mosolgo, licensed under the MIT License:

> Copyright 2015 Robert Mosolgo
>
> Permission is hereby granted, free of charge, to any person obtaining
> a copy of this software and associated documentation files (the
> "Software"), to deal in the Software without restriction, including
> without limitation the rights to use, copy, modify, merge, publish,
> distribute, sublicense, and/or sell copies of the Software, and to
> permit persons to whom the Software is furnished to do so, subject to
> the following conditions:
>
> The above copyright notice and this permission notice shall be
> included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
> EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
> MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
> NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
> LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
> OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
> WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Translations and other original content in this repository are also released under the MIT License.
