// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  modules: ['@nuxtjs/tailwindcss'],
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
  }
})
