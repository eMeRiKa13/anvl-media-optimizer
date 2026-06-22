// https://nuxt.com/docs/api/configuration/nuxt-config
const hmrPort = Number(process.env.ANVL_HMR_PORT || 4351)

export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: process.env.NUXT_DEVTOOLS !== 'false' },
  modules: ['@nuxtjs/tailwindcss'],
  vite: {
    server: {
      hmr: {
        host: '127.0.0.1',
        port: hmrPort,
        clientPort: hmrPort
      }
    }
  },
  hooks: {
    'vite:extendConfig'(config) {
      config.server = config.server || {}
      const currentHmr = typeof config.server.hmr === 'object' ? config.server.hmr : {}
      config.server.hmr = {
        ...currentHmr,
        host: '127.0.0.1',
        port: hmrPort,
        clientPort: hmrPort
      }
    }
  },
  app: {
    head: {
      title: 'ANVL - Smash Your Images and Audio!',
      meta: [
        { name: 'description', content: 'ANVL is a Pop Art-styled image optimizer that smashes your JPGs and PNGs into highly compressed AVIF and WebP formats, and your WAVs into highly compressed MP3 formats.' },
        // Open Graph
        { property: 'og:title', content: 'ANVL - Smash Your Images and Audio!' },
        { property: 'og:description', content: 'Smash your images and audio into optimized formats with ANVL.' },
        { property: 'og:image', content: '/logo.jpg' },
        { property: 'og:type', content: 'website' },
        // Twitter
        { name: 'twitter:card', content: 'summary_large_image' },
        { name: 'twitter:title', content: 'ANVL - Smash Your Images and Audio!' },
        { name: 'twitter:description', content: 'Smash your images and audio into optimized formats with ANVL.' },
        { name: 'twitter:image', content: '/logo.jpg' }
      ],
      link: [
        { rel: 'icon', type: 'image/png', href: '/favicon.png' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Bangers&family=Outfit:wght@400;500;700;900&display=swap' }
      ]
    }
  },
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || 'http://127.0.0.1:4000',
      nativeFileToken: process.env.NUXT_PUBLIC_NATIVE_FILE_TOKEN || ''
    }
  }
})
