// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://shuheix.github.io',
	base: '/graphql-ruby-guides-i18n',
	integrations: [
		starlight({
			title: 'graphql-ruby guides i18n',
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/shuheix/graphql-ruby-guides-i18n' }],
			defaultLocale: 'en',
			locales: {
				en: { label: 'English' },
				ja: { label: '日本語', lang: 'ja' },
			},
			sidebar: [
				{ label: 'Home', link: '/' },
			],
		}),
	],
});