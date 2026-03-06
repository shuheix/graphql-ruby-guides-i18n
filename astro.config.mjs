// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://shuheix.github.io',
	base: '/graphql-ruby-guides-i18n',
	integrations: [
		starlight({
			title: 'graphql-ruby Guides i18n',
			editLink: {
				baseUrl: 'https://github.com/shuheix/graphql-ruby-guides-i18n/edit/main/',
			},
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/shuheix/graphql-ruby-guides-i18n' }],
			locales: {
				root: {
					label: 'English',
					lang: 'en',
				},
				ja: {
					label: '日本語',
					lang: 'ja',
				},
			},
			sidebar: [
				{
					label: 'Guides',
					autogenerate: { directory: 'guides' },
				},
			],
		}),
	],
});