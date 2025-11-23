<script setup lang="ts">
import { ref } from 'vue'
import { useDropZone } from '@vueuse/core'

interface ProcessedResult {
  originalName: string
  avif: string
  webp: string
  resizedOriginal?: string
  originalSize: number
  avifSize: number
  webpSize: number
  resizedOriginalSize?: number
}

interface FileItem {
  file: File
  id: string
  status: 'pending' | 'processing' | 'done'
  result?: ProcessedResult
  resize?: { width: number; height: number; quality: number }
}

const files = ref<FileItem[]>([])
const isProcessing = ref(false)
const isDownloading = ref(false)
const dropZoneRef = ref<HTMLElement>()
const fileInput = ref<HTMLInputElement>()

// Resize Modal State
const showResizeModal = ref(false)
const currentResizeFileId = ref<string | null>(null)
const resizeWidth = ref<number>(0)
const resizeHeight = ref<number>(0)
const resizeQuality = ref<number>(80)
const aspectRatio = ref<number>(0)

function onDrop(droppedFiles: File[] | null) {
  if (!droppedFiles) return
  addFiles(droppedFiles)
}

function onFileSelect(event: Event) {
  const input = event.target as HTMLInputElement
  if (input.files) {
    addFiles(Array.from(input.files))
  }
}

function addFiles(newFiles: File[]) {
  const remainingSlots = 50 - files.value.length
  if (remainingSlots <= 0) {
    alert('Maximum limit of 50 files reached.')
    return
  }

  const filesToAdd = newFiles.slice(0, remainingSlots)
  
  if (newFiles.length > remainingSlots) {
    alert(`Only adding ${remainingSlots} files. Maximum limit of 50 files reached.`)
  }

  const mappedFiles = filesToAdd.map(file => ({
    file,
    id: Math.random().toString(36).substr(2, 9),
    status: 'pending' as const,
    result: undefined
  }))
  files.value = [...mappedFiles, ...files.value]
}

const { isOverDropZone } = useDropZone(dropZoneRef, {
  onDrop,
  dataTypes: ['image/jpeg', 'image/png']
})

// Resize Logic
function openResizeModal(fileItem: FileItem) {
  currentResizeFileId.value = fileItem.id
  const img = new Image()
  img.onload = () => {
    resizeWidth.value = fileItem.resize?.width || img.naturalWidth
    resizeHeight.value = fileItem.resize?.height || img.naturalHeight
    resizeQuality.value = fileItem.resize?.quality || 80
    aspectRatio.value = img.naturalWidth / img.naturalHeight
    showResizeModal.value = true
  }
  img.src = URL.createObjectURL(fileItem.file)
}

function updateDimensions(type: 'width' | 'height') {
  if (type === 'width') {
    resizeHeight.value = Math.round(resizeWidth.value / aspectRatio.value)
  } else {
    resizeWidth.value = Math.round(resizeHeight.value * aspectRatio.value)
  }
}

function saveResize() {
  if (currentResizeFileId.value) {
    const index = files.value.findIndex(f => f.id === currentResizeFileId.value)
    if (index !== -1) {
      files.value[index].resize = {
        width: resizeWidth.value,
        height: resizeHeight.value,
        quality: resizeQuality.value
      }
    }
  }
  closeResizeModal()
}

function closeResizeModal() {
  showResizeModal.value = false
  currentResizeFileId.value = null
}

async function processImages() {
  isProcessing.value = true
  const pendingFiles = files.value.filter(f => f.status === 'pending')

  if (pendingFiles.length === 0) {
    isProcessing.value = false
    return
  }

  const formData = new FormData()
  pendingFiles.forEach(f => {
    formData.append('images', f.file)
    if (f.resize) {
      formData.append(`resize_${f.file.name}`, JSON.stringify(f.resize))
    }
  })

  try {
    files.value = files.value.map(f => 
      f.status === 'pending' ? { ...f, status: 'processing' } : f
    )

    const response = await fetch('http://localhost:4000/api/process', {
      method: 'POST',
      body: formData
    })

    const data = await response.json()

    files.value = files.value.map(f => {
      const result = data.results.find((r: ProcessedResult) => r.originalName === f.file.name)
      if (result) {
        return { ...f, status: 'done', result }
      }
      return f
    })

  } catch (error) {
    console.error("Error processing:", error)
    alert("Something went wrong processing the images.")
  } finally {
    isProcessing.value = false
  }
}

function triggerFileInput() {
  fileInput.value?.click()
}

function formatSize(bytes: number) {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
}

function calculateSavings(original: number, compressed: number) {
  const savings = ((original - compressed) / original) * 100
  return Math.round(savings)
}

function getSnippet(filename: string) {
  const name = filename.substring(0, filename.lastIndexOf('.')) || filename
  return `<picture>
  <source srcset="/img/${name}.avif" type="image/avif" />
  <source srcset="/img/${name}.webp" type="image/webp" />
  <img src="/img/${filename}" alt="" />
</picture>`
}

function copyToClipboard(text: string) {
  navigator.clipboard.writeText(text)
}

async function downloadAll() {
  const processedFiles = files.value.filter(f => f.status === 'done' && f.result)
  
  if (processedFiles.length === 0) return

  isDownloading.value = true

  const allFilePaths = processedFiles.flatMap(f => {
    if (!f.result) return []
    const paths = [f.result.avif, f.result.webp]
    if (f.result.resizedOriginal) {
      paths.push(f.result.resizedOriginal)
    }
    return paths
  })

  try {
    const response = await fetch('http://localhost:4000/api/zip', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ files: allFilePaths })
    })

    if (!response.ok) throw new Error('Download failed')

    const blob = await response.blob()
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'images.zip'
    document.body.appendChild(a)
    a.click()
    window.URL.revokeObjectURL(url)
    document.body.removeChild(a)

  } catch (error) {
    console.error('Download error:', error)
    alert('Failed to download zip file')
  } finally {
    isDownloading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-white font-outfit p-8 flex justify-center selection:bg-yellow-300 selection:text-black">
    <div class="w-full max-w-[1000px]">
      
      <header class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-6">
          <div class="w-48 h-48 flex items-center justify-center transform -rotate-3 hover:rotate-0 transition-transform duration-300">
            <img src="/logo.jpg" alt="Anvl Logo" class="w-full h-full object-contain" />
          </div>
          <div class="-mt-4 flex flex-col gap-1">
            <h1 class="text-7xl font-bangers tracking-wider text-red-500 drop-shadow-[3px_3px_0px_rgba(0,0,0,1)] stroke-black" style="-webkit-text-stroke: 2px black;">ANVL</h1>
            <h2 class="text-black font-bold text-xl bg-yellow-400 inline-block px-3 border-2 border-black shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] transform rotate-1">SMASH YOUR IMAGES!</h2>
          </div>
        </div>
      </header>

      <main class="bg-yellow-50 border-4 border-black shadow-[12px_12px_0px_0px_rgba(0,0,0,1)] rounded-3xl p-8 relative overflow-hidden">
        <!-- Halftone pattern decoration -->
        <div class="absolute top-0 right-0 w-64 h-64 bg-[radial-gradient(circle,rgba(59,130,246,0.2)_2px,transparent_2.5px)] bg-[length:12px_12px] opacity-50 pointer-events-none"></div>

        <div 
          ref="dropZoneRef"
          @click="triggerFileInput"
          class="group relative border-4 border-dashed border-black rounded-2xl p-10 text-center transition-all duration-300 cursor-pointer overflow-hidden bg-blue-100 hover:bg-blue-200"
          :class="[isOverDropZone ? 'bg-blue-300 scale-[1.02]' : '']"
        >
          <input 
            ref="fileInput"
            type="file" 
            multiple 
            accept="image/jpeg,image/png" 
            class="hidden" 
            @change="onFileSelect"
          />
          
          <div class="relative z-10 flex flex-col items-center gap-4">
            <div class="w-24 h-24 bg-yellow-400 border-4 border-black rounded-full flex items-center justify-center mb-2 group-hover:scale-110 transition-transform duration-300 shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-12 h-12 text-black">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
              </svg>
            </div>
            <h3 class="text-4xl font-bangers text-black tracking-wide group-hover:text-blue-700 transition-colors">
              {{ isOverDropZone ? 'DROP IT HERE!' : 'UPLOAD IMAGES' }}
            </h3>
            <p class="text-black font-bold text-lg bg-white px-4 py-1 border-2 border-black inline-block transform -rotate-1 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)]">JPG or PNG</p>
          </div>
        </div>

        <div v-if="files.length > 0" class="mt-12 space-y-6">
          <div class="flex items-center justify-between border-b-4 border-black pb-4">
            <h2 class="text-3xl font-bangers text-black tracking-wide">
              IMAGES 
              <span class="ml-2 text-xl font-outfit font-bold" :class="files.length >= 50 ? 'text-red-600' : 'text-blue-400'">
                ({{ files.length }} / 50)
              </span>
            </h2>
            <button 
              v-if="files.some(f => f.status === 'done')"
              @click="downloadAll"
              :disabled="isDownloading"
              class="ml-auto bg-blue-500 text-white px-8 py-3 rounded-xl font-bangers text-2xl tracking-wide border-4 border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[2px] hover:translate-y-[2px] hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] active:translate-x-[6px] active:translate-y-[6px] active:shadow-none transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-x-0 disabled:hover:translate-y-0 disabled:hover:shadow-[6px_6px_0px_0px_rgba(0,0,0,1)]"
            >
              <span v-if="isDownloading" class="flex items-center gap-2">
                <svg class="animate-spin h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                ZIPPING...
              </span>
              <span v-else>DOWNLOAD ALL ZIP</span>
            </button>

            <button 
              @click="processImages"
              :disabled="isProcessing || !files.some(f => f.status === 'pending')"
              class="ml-4 bg-red-500 text-white px-8 py-3 rounded-xl font-bangers text-2xl tracking-wide border-4 border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[2px] hover:translate-y-[2px] hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] active:translate-x-[6px] active:translate-y-[6px] active:shadow-none transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-x-0 disabled:hover:translate-y-0 disabled:hover:shadow-[6px_6px_0px_0px_rgba(0,0,0,1)]"
            >
              <span v-if="isProcessing" class="flex items-center gap-2">
                <svg class="animate-spin h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                SMASHING...
              </span>
              <span v-else>SMASH ALL IMAGES!</span>
            </button>
          </div>

          <div class="grid gap-4">
            <div v-for="fileItem in files" :key="fileItem.id" class="group bg-white border-4 border-black rounded-xl p-4 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:-translate-y-0.5 transition-all duration-300 flex items-center">
              
              <!-- Left Side: File Info -->
              <div class="w-2/5 flex items-center gap-4 pr-4 border-r-2 border-black border-dashed">
                <div class="w-14 h-14 bg-yellow-300 border-2 border-black rounded-lg flex items-center justify-center text-2xl shrink-0 shadow-[1px_1px_0px_0px_rgba(0,0,0,1)]">
                  🖼️
                </div>
                <div class="min-w-0">
                  <div class="font-bold text-black text-lg font-bangers tracking-wide truncate" :title="fileItem.file.name">{{ fileItem.file.name }}</div>
                  <div class="text-black font-bold text-sm bg-blue-100 inline-block px-2 border-2 border-black rounded">{{ formatSize(fileItem.file.size) }}</div>
                  <button 
                    @click="openResizeModal(fileItem)"
                    class="text-white font-bold text-sm bg-red-500 inline-block px-2 border-2 border-black rounded ml-2 cursor-pointer hover:bg-red-600 transition-colors"
                  >
                    Resize {{ fileItem.resize ? `(${fileItem.resize.width}x${fileItem.resize.height})` : '' }}
                  </button>
                </div>
              </div>

              <!-- Right Side: Actions & Results -->
              <div class="w-3/5 flex items-center justify-end gap-3 pl-4">
                
                <!-- Status: Pending/Processing -->
                <div v-if="fileItem.status !== 'done'" class="flex-1 flex justify-end font-bangers">
                  <span v-if="fileItem.status === 'pending'" class="px-4 py-1 rounded-lg font-bold uppercase bg-blue-200 text-black border-2 border-black">Ready to smash</span>
                  <span v-if="fileItem.status === 'processing'" class="px-4 py-1 rounded-lg font-bold uppercase bg-yellow-300 text-black border-2 border-black animate-pulse shadow-[2px_2px_0px_0px_rgba(0,0,0,1)]">Smashing...</span>
                </div>

                <!-- Results: Done -->
                <template v-else-if="fileItem.result">
                 
                  <!-- JPG / PNG Pill -->
                  <div v-if="fileItem.result.resizedOriginal" class="flex items-center bg-red-100 rounded-lg border-2 border-black overflow-hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] hover:translate-y-[-1px] transition-transform">
                    <div class="px-3 py-1 flex flex-col justify-center border-r-2 border-black bg-red-200">
                      <div class="flex items-center gap-1.5">
                        <span class="font-black text-black text-sm font-bangers tracking-wide">{{ fileItem.file.name.split('.').pop()?.toUpperCase() }}</span>
                      </div>
                      <div class="text-black text-[10px] font-bold">
                        {{ formatSize(fileItem.result.resizedOriginalSize || 0) }}
                      </div>
                    </div>
                    <a :href="`http://localhost:4000${fileItem.result.resizedOriginal}`" target="_blank" download class="px-2 py-3 hover:bg-red-300 text-black transition-colors flex items-center justify-center bg-white">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-5 h-5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M12 12.75l-3 3m0 0l-3-3m3 3V3" />
                      </svg>
                    </a>
                  </div>
                  
                  <!-- AVIF Pill -->
                  <div class="flex items-center bg-green-100 rounded-lg border-2 border-black overflow-hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] hover:translate-y-[-1px] transition-transform">
                    <div class="px-3 py-1 flex flex-col justify-center border-r-2 border-black bg-green-200">
                      <div class="flex items-center gap-1.5">
                        <span class="font-black text-black text-sm font-bangers tracking-wide">AVIF</span>
                        <span class="bg-black text-white text-[10px] font-bold px-1.5 py-0.5 rounded">
                          -{{ calculateSavings(fileItem.result.originalSize, fileItem.result.avifSize) }}%
                        </span>
                      </div>
                      <div class="text-black text-[10px] font-bold">
                        {{ formatSize(fileItem.result.avifSize) }}
                      </div>
                    </div>
                    <a :href="`http://localhost:4000${fileItem.result.avif}`" target="_blank" download class="px-2 py-3 hover:bg-green-300 text-black transition-colors flex items-center justify-center bg-white">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-5 h-5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M12 12.75l-3 3m0 0l-3-3m3 3V3" />
                      </svg>
                    </a>
                  </div>

                  <!-- WebP Pill -->
                  <div class="flex items-center bg-blue-100 rounded-lg border-2 border-black overflow-hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] hover:translate-y-[-1px] transition-transform">
                    <div class="px-3 py-1 flex flex-col justify-center border-r-2 border-black bg-blue-200">
                      <div class="flex items-center gap-1.5">
                        <span class="font-black text-black text-sm font-bangers tracking-wide">WebP</span>
                        <span class="bg-black text-white text-[10px] font-bold px-1.5 py-0.5 rounded">
                          -{{ calculateSavings(fileItem.result.originalSize, fileItem.result.webpSize) }}%
                        </span>
                      </div>
                      <div class="text-black text-[10px] font-bold">
                        {{ formatSize(fileItem.result.webpSize) }}
                      </div>
                    </div>
                    <a :href="`http://localhost:4000${fileItem.result.webp}`" target="_blank" download class="px-2 py-3 hover:bg-blue-300 text-black transition-colors flex items-center justify-center bg-white">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-5 h-5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M12 12.75l-3 3m0 0l-3-3m3 3V3" />
                      </svg>
                    </a>
                  </div>

                  <!-- Code Button -->
                  <button 
                    @click="copyToClipboard(getSnippet(fileItem.file.name))"
                    class="w-10 h-10 bg-black text-white rounded-lg flex items-center justify-center hover:bg-gray-800 hover:scale-105 transition-all shadow-[2px_2px_0px_0px_rgba(100,100,100,1)] border-2 border-transparent"
                    title="Copy Code Snippet"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-5 h-5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 18" />
                    </svg>
                  </button>

                  <!-- Preview Button -->

                </template>
              </div>

            </div>
          </div>
        </div>
      </main>

      <footer class="mt-12 text-center">
        <p class="font-bold text-lg text-black/30">
          By <a href="https://enchanter.gg/en/" target="_blank" class="underline decoration-2 hover:text-blue-600 hover:decoration-blue-600 transition-all">Antoine Frankart</a>
        </p>
      </footer>

    </div>

    <!-- Resize Modal -->
    <div v-if="showResizeModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 backdrop-blur-sm">
      <div class="bg-white border-4 border-black p-8 rounded-2xl shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] max-w-md w-full mx-4">
        <h3 class="text-3xl font-bangers text-black mb-6 text-center">RESIZE IMAGE</h3>
        
        <div class="space-y-4">
          <div>
            <label class="block font-bold text-black mb-1">Width (px)</label>
            <input 
              type="number" 
              v-model.number="resizeWidth" 
              @input="updateDimensions('width')"
              class="w-full border-2 border-black p-2 rounded-lg font-bold"
            >
          </div>
          
          <div>
            <label class="block font-bold text-black mb-1">Height (px)</label>
            <input 
              type="number" 
              v-model.number="resizeHeight" 
              @input="updateDimensions('height')"
              class="w-full border-2 border-black p-2 rounded-lg font-bold"
            >
          </div>

          <div>
            <label class="block font-bold text-black mb-1">Quality ({{ resizeQuality }}%)</label>
            <input 
              type="range" 
              v-model.number="resizeQuality" 
              min="1" 
              max="100"
              class="w-full h-4 bg-gray-200 rounded-lg appearance-none cursor-pointer border-2 border-black accent-yellow-400"
            >
          </div>

          <div class="flex gap-4 mt-8">
            <button 
              @click="closeResizeModal"
              class="flex-1 bg-gray-200 text-black font-bold py-2 rounded-lg border-2 border-black hover:bg-gray-300 transition-colors"
            >
              CANCEL
            </button>
            <button 
              @click="saveResize"
              class="flex-1 bg-yellow-400 text-black font-bold py-2 rounded-lg border-2 border-black shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[1px] hover:translate-y-[1px] hover:shadow-[1px_1px_0px_0px_rgba(0,0,0,1)] active:shadow-none transition-all"
            >
              SAVE
            </button>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<style>
/* Custom styles if needed */
</style>
