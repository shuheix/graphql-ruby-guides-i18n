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
			defaultLocale: 'en',
			locales: {
				en: {
					label: 'English',
					lang: 'en',
				},
				ja: {
					label: '日本語',
					lang: 'ja',
				},
			},
			sidebar: [
				{ label: 'Getting Started', slug: 'getting_started' },
				{ label: 'Schema', autogenerate: { directory: 'schema' } },
				{ label: 'Queries', autogenerate: { directory: 'queries' } },
				{ label: 'Type Definitions', autogenerate: { directory: 'type_definitions' } },
				{ label: 'Authorization', autogenerate: { directory: 'authorization' } },
				{ label: 'Fields', autogenerate: { directory: 'fields' } },
				{ label: 'Mutations', autogenerate: { directory: 'mutations' } },
				{ label: 'Errors', autogenerate: { directory: 'errors' } },
				{ label: 'Pagination', autogenerate: { directory: 'pagination' } },
				{ label: 'Relay', autogenerate: { directory: 'relay' } },
				{ label: 'Dataloader', autogenerate: { directory: 'dataloader' } },
				{ label: 'Subscriptions', autogenerate: { directory: 'subscriptions' } },
				{ label: 'Execution', autogenerate: { directory: 'execution' } },
				{ label: 'GraphQL Pro', autogenerate: { directory: 'pro' } },
				{ label: 'OperationStore', autogenerate: { directory: 'operation_store' } },
				{ label: 'Defer', autogenerate: { directory: 'defer' } },
				{ label: 'Rate Limiters', autogenerate: { directory: 'limiters' } },
				{ label: 'Object Cache', autogenerate: { directory: 'object_cache' } },
				{ label: 'Changesets', autogenerate: { directory: 'changesets' } },
				{ label: 'JavaScript Client', autogenerate: { directory: 'javascript_client' } },
				{ label: 'Language Tools', autogenerate: { directory: 'language_tools' } },
				{ label: 'Testing', autogenerate: { directory: 'testing' } },
				{ label: 'Other', items: [
					{ slug: 'faq' },
					{ slug: 'related_projects' },
					{ slug: 'development' },
				]},
			],
		}),
	],
});