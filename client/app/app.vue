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
  lqip: string
}

interface AudioResult {
  originalName: string
  mp3: string
  originalSize: number
  mp3Size: number
}

interface FileItem {
  file: File
  id: string
  status: 'pending' | 'processing' | 'done'
  result?: ProcessedResult
  audioResult?: AudioResult
  resize?: { width: number; height: number; quality: number }
  audioConfig?: { bitrate: string; channels: string; speed: number }
}

const files = ref<FileItem[]>([])
const audioFiles = ref<FileItem[]>([])
const isProcessing = ref(false)
const isDownloading = ref(false)
const dropZoneRef = ref<HTMLElement>()
const dropZoneAudioRef = ref<HTMLElement>()
const fileInput = ref<HTMLInputElement>()
const audioInput = ref<HTMLInputElement>()

const activeMode = ref<'split' | 'image' | 'audio'>('split')

// Resize Modal State
const showResizeModal = ref(false)
const currentResizeFileId = ref<string | null>(null)
const resizeWidth = ref<number>(0)
const resizeHeight = ref<number>(0)
const resizeQuality = ref<number>(80)
const aspectRatio = ref<number>(0)

// Audio Config Functions
function openAudioConfigModal(fileItem: FileItem) {
  currentAudioFileId.value = fileItem.id
  // Load existing config or defaults
  if (fileItem.audioConfig) {
    audioOptions.value = { ...fileItem.audioConfig }
  } else {
    audioOptions.value = { bitrate: '192k', channels: 'stereo', speed: 1.0 }
  }
  showAudioConfigModal.value = true
}

function closeAudioConfigModal() {
  showAudioConfigModal.value = false
  currentAudioFileId.value = null
}

function saveAudioConfig() {
  if (currentAudioFileId.value) {
    const index = audioFiles.value.findIndex(f => f.id === currentAudioFileId.value)
    if (index !== -1 && audioFiles.value[index]) {
      audioFiles.value[index].audioConfig = { ...audioOptions.value }
    }
  }
  closeAudioConfigModal()
}

// Preview Modal State
const showPreviewModal = ref(false)
const previewFile = ref<FileItem | null>(null)
const previewFormat = ref<'avif' | 'webp' | 'resized'>('avif')
const sliderPosition = ref(50)
const previewOriginalUrl = ref<string>('')

// Audio Config State
const showAudioConfigModal = ref(false)
const currentAudioFileId = ref<string | null>(null)
const audioOptions = ref({
  bitrate: '192k',
  channels: 'stereo',
  speed: 1.0
})

function onDropImages(droppedFiles: File[] | null) {
  if (!droppedFiles) return
  if (activeMode.value === 'split') activeMode.value = 'image'
  addFiles(droppedFiles, 'image')
}

function resetToSplitMode() {
  activeMode.value = 'split'
}

function onDropAudio(droppedFiles: File[] | null) {
  if (!droppedFiles) return
  if (activeMode.value === 'split') activeMode.value = 'audio'
  addFiles(droppedFiles, 'audio')
}

function onFileSelect(event: Event, type: 'image' | 'audio') {
  const input = event.target as HTMLInputElement
  if (input.files) {
    if (activeMode.value === 'split') activeMode.value = type
    addFiles(Array.from(input.files), type)
  }
}

function addFiles(newFiles: File[], type: 'image' | 'audio') {
  const targetList = type === 'image' ? files : audioFiles
  const limit = 50
  
  const remainingSlots = limit - targetList.value.length
  if (remainingSlots <= 0) {
    alert('Maximum limit of 50 files reached.')
    return
  }

  const filesToAdd = newFiles.slice(0, remainingSlots)
  
  if (newFiles.length > remainingSlots) {
    alert(`Only adding ${remainingSlots} files. Maximum limit of 50 files reached.`)
  }

  const mappedFiles: FileItem[] = filesToAdd.map(file => ({
    file,
    id: Math.random().toString(36).substr(2, 9),
    status: 'pending' as const,
    result: undefined
  }))
  
  if (type === 'image') {
    files.value = [...mappedFiles, ...files.value]
  } else {
    audioFiles.value = [...mappedFiles, ...audioFiles.value]
  }
}

const { isOverDropZone: isOverImageZone } = useDropZone(dropZoneRef, {
  onDrop: onDropImages,
  dataTypes: ['image/jpeg', 'image/png']
})

const { isOverDropZone: isOverAudioZone } = useDropZone(dropZoneAudioRef, {
  onDrop: onDropAudio,
  dataTypes: ['audio/wav']
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
    if (index !== -1 && files.value[index]) {
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

// Preview Logic
function openPreviewModal(fileItem: FileItem) {
  previewFile.value = fileItem
  previewOriginalUrl.value = URL.createObjectURL(fileItem.file)
  previewFormat.value = 'avif'
  sliderPosition.value = 50
  showPreviewModal.value = true
}

function closePreviewModal() {
  showPreviewModal.value = false
  previewFile.value = null
  if (previewOriginalUrl.value) {
    URL.revokeObjectURL(previewOriginalUrl.value)
    previewOriginalUrl.value = ''
  }
}

function getPreviewUrl() {
  if (!previewFile.value?.result) return ''
  switch (previewFormat.value) {
    case 'avif': return `${apiBase}${previewFile.value.result.avif}`
    case 'webp': return `${apiBase}${previewFile.value.result.webp}`
    case 'resized': return `${apiBase}${previewFile.value.result.resizedOriginal}`
    default: return ''
  }
}

const config = useRuntimeConfig()
const apiBase = config.public.apiBase
const apiUrl = `${apiBase}/api`

const processImages = async () => {
  if (isProcessing.value) return
  isProcessing.value = true

  const formData = new FormData()
  files.value.forEach(f => {
    if (f.status === 'pending') {
      f.status = 'processing'
      formData.append('images', f.file) // Matches 'images' field in multer
    }
  })

  // Also send resize options
  const resizeOptions = files.value.reduce((acc, f) => {
    if (f.resize) {
      acc[f.file.name] = f.resize
    }
    return acc
  }, {} as Record<string, any>)
  formData.append('resizeOptions', JSON.stringify(resizeOptions))

  try {
    const data = await $fetch<{ files: ProcessedResult[] }>(`${apiUrl}/process-images`, {
      method: 'POST',
      body: formData
    })

    // Update file statuses
    data.files.forEach(result => {
      const fileIndex = files.value.findIndex(f => f.file.name === result.originalName)
      if (fileIndex !== -1) {
        files.value[fileIndex].status = 'done'
        files.value[fileIndex].result = result
      }
    })
  } catch (error) {
    console.error('Error processing images:', error)
    files.value.forEach(f => {
      if (f.status === 'processing') f.status = 'pending' // Revert on error
    })
    alert("Something went wrong processing the images.")
  } finally {
    isProcessing.value = false
  }
}

const processAudio = async () => {
  if (isProcessing.value) return
  isProcessing.value = true

  const formData = new FormData()
  audioFiles.value.forEach(f => {
      if (f.status === 'pending') {
        f.status = 'processing'
        formData.append('audio', f.file)
      }
  })

  // Collect audio config
  const audioConfigs = audioFiles.value.reduce((acc, f) => {
    if (f.audioConfig) {
      acc[f.file.name] = f.audioConfig
    }
    return acc
  }, {} as Record<string, any>)
  formData.append('audioConfigs', JSON.stringify(audioConfigs))

  try {
      const data = await $fetch<{ files: AudioResult[] }>(`${apiUrl}/process-audio`, {
        method: 'POST',
        body: formData
      })

      data.files.forEach(result => {
        const fileIndex = audioFiles.value.findIndex(f => f.file.name === result.originalName)
        if (fileIndex !== -1) {
            audioFiles.value[fileIndex].status = 'done'
            audioFiles.value[fileIndex].audioResult = result
        }
      })
  } catch (error) {
      console.error("Error processing audio", error)
      audioFiles.value.forEach(f => {
        if (f.status === 'processing') f.status = 'pending'
      })
      alert("Something went wrong processing the audio.")
  } finally {
    isProcessing.value = false
  }
}

function triggerFileInput(type: 'image' | 'audio') {
  if (type === 'image') fileInput.value?.click()
  else audioInput.value?.click()
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

const downloadAll = async () => {
  if (isDownloading.value) return
  isDownloading.value = true

  try {
    const allProcessed = [...files.value, ...audioFiles.value]
      .filter(f => f.status === 'done' && (f.result || f.audioResult))
      .map(f => {
          if (f.result) {
               return [f.result.avif, f.result.webp, f.result.resizedOriginal].filter(Boolean)
          } else if (f.audioResult) {
              return [f.audioResult.mp3]
          }
          return []
      })
      .flat()

    if (allProcessed.length === 0) return

    const response = await fetch(`${apiUrl}/download-zip`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ files: allProcessed })
    })

    if (response.ok) {
      const blob = await response.blob()
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'anvl-processed.zip'
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      a.remove()
    }
  } catch (error) {
    console.error('Error downloading zip:', error)
  } finally {
    isDownloading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-white font-outfit p-8 flex justify-center selection:bg-yellow-300 selection:text-black">
    <div class="w-full max-w-[1200px]">
      
      <header class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-6">
          <div class="w-48 h-48 flex items-center justify-center transform -rotate-3 hover:rotate-0 transition-transform duration-300">
            <img src="/logo.jpg" alt="Anvl Logo" class="w-full h-full object-contain" />
          </div>
          <div class="-mt-4 flex flex-col gap-1">
            <h1 class="text-7xl font-bangers tracking-wider text-red-500 drop-shadow-[3px_3px_0px_rgba(0,0,0,1)] stroke-black" style="-webkit-text-stroke: 2px black;">ANVL</h1>
            <h2 class="text-black font-bold text-xl bg-yellow-400 inline-block px-3 border-2 border-black shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] transform rotate-1">SMASH YOUR IMAGES AND AUDIO!</h2>
          </div>
        </div>
      </header>

      <main class="relative bg-yellow-50 border-4 border-black shadow-[12px_12px_0px_0px_rgba(0,0,0,1)] rounded-3xl p-8 overflow-hidden">
        <!-- Halftone pattern decoration -->
        <div class="absolute top-0 right-0 w-64 h-64 bg-[radial-gradient(circle,rgba(59,130,246,0.2)_2px,transparent_2.5px)] bg-[length:12px_12px] opacity-50 pointer-events-none"></div>

        <!-- Back Button (Only visible when not in split mode) -->
        <button 
          v-if="activeMode !== 'split'"
          @click="resetToSplitMode"
          class="absolute top-4 right-4 z-50 bg-white border-4 border-black px-4 py-1 rounded-xl font-bangers text-xl shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[2px] hover:translate-y-[2px] hover:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] hover:bg-gray-100 transition-all"
        >
          ← BACK TO SELECTION
        </button>

        <!-- Drop Zone Container -->
        <div class="flex w-full gap-0 relative transition-all duration-500 border-4 border-dashed border-black rounded-2xl" :class="activeMode === 'split' ? 'h-[600px]' : 'h-auto min-h-[300px]'">
          
          <!-- LEFT: Image Drop Zone -->
          <div 
            class="relative flex flex-col transition-all duration-500 ease-in-out border-black overflow-hidden bg-blue-50"
            :class="[
              activeMode === 'split' ? 'w-1/2 hover:bg-blue-200 border-r-4 rounded-tl-2xl rounded-bl-2xl' :
              activeMode === 'image' ? 'w-full rounded-2xl bg-blue-100 hover:bg-blue-200' : 'w-0 border-r-0 opacity-0 pointer-events-none'
            ]"
          >
            <div 
              ref="dropZoneRef"
              @click="activeMode === 'split' ? (activeMode = 'image') : triggerFileInput('image')"
              class="h-full flex flex-col items-center justify-center p-8 cursor-pointer group transition-colors relative z-10"
              :class="[isOverImageZone ? 'bg-blue-300' : '']"
            >
               <input 
                ref="fileInput"
                type="file" 
                multiple 
                accept="image/jpeg,image/png" 
                class="hidden" 
                @change="(e) => onFileSelect(e, 'image')"
              />

              <div class="w-24 h-24 bg-blue-400 border-4 border-black rounded-full flex items-center justify-center mb-6 shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] group-hover:scale-110 transition-transform duration-300">
                <span class="text-4xl">🖼️</span>
              </div>
              <h3 class="text-5xl font-bangers text-black tracking-wide mb-2 text-center group-hover:text-blue-600 transition-colors">
                {{ isOverImageZone ? 'DROP IMAGES!' : 'SMASH IMAGES' }}
              </h3>
              <p class="font-bold text-lg bg-white px-4 py-1 border-2 border-black inline-block transform -rotate-1 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)]">JPG or PNG</p>
            </div>
          </div>

          <!-- RIGHT: Audio Drop Zone -->
          <div 
             class="relative flex flex-col transition-all duration-500 ease-in-out border-black overflow-hidden bg-green-50"
             :class="[
               activeMode === 'split' ? 'w-1/2 hover:bg-green-200 border-l-4 rounded-tr-2xl rounded-br-2xl' :
               activeMode === 'audio' ? 'w-full rounded-2xl bg-green-100 hover:bg-green-200' : 'w-0 border-l-0 opacity-0 pointer-events-none'
             ]"
          >
             <div 
              ref="dropZoneAudioRef"
              @click="activeMode === 'split' ? (activeMode = 'audio') : triggerFileInput('audio')"
              class="h-full flex flex-col items-center justify-center p-8 cursor-pointer group transition-colors relative z-10"
              :class="[isOverAudioZone ? 'bg-green-200' : '']"
             >
                <input 
                  ref="audioInput"
                  type="file" 
                  multiple 
                  accept=".wav,audio/wav" 
                  class="hidden" 
                  @change="(e) => onFileSelect(e, 'audio')"
                />
 
               <div class="w-24 h-24 bg-green-400 border-4 border-black rounded-full flex items-center justify-center mb-6 shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] group-hover:scale-110 transition-transform duration-300">
                 <span class="text-4xl">🎵</span>
               </div>
               <h3 class="text-5xl font-bangers text-black tracking-wide mb-2 text-center group-hover:text-green-600 transition-colors">
                 {{ isOverAudioZone ? 'DROP WAV!' : 'SMASH AUDIO' }}
               </h3>
               <p class="font-bold text-lg bg-white px-4 py-1 border-2 border-black inline-block transform -rotate-1 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)]">WAV to MP3</p>
             </div>
          </div>
        </div>

        <!-- IMAGE LIST (Original Layout) -->
        <div v-if="activeMode === 'image' && files.length > 0" class="mt-12 space-y-6 animate-fade-in">
          <div class="flex items-center justify-between border-b-2 border-dashed border-black pb-8">
            <h2 class="text-3xl font-bangers text-black tracking-wide">
              IMAGES 
              <span class="ml-2 text-xl font-outfit font-bold" :class="files.length >= 50 ? 'text-red-600' : 'text-blue-400'">
                ({{ files.length }} / 50)
              </span>
            </h2>
            <div class="flex gap-4">
              <button 
                v-if="files.some(f => f.status === 'done')"
                @click="downloadAll"
                :disabled="isDownloading"
                class="bg-blue-500 text-white px-8 py-3 rounded-xl font-bangers text-2xl tracking-wide border-4 border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[2px] hover:translate-y-[2px] hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] active:translate-x-[6px] active:translate-y-[6px] active:shadow-none transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-x-0 disabled:hover:translate-y-0 disabled:hover:shadow-[6px_6px_0px_0px_rgba(0,0,0,1)]"
              >
                <span v-if="isDownloading" class="flex items-center gap-2">
                  <svg class="animate-spin h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  ZIPPING...
                </span>
                <span v-else>DOWNLOAD ZIP</span>
              </button>

              <button 
                @click="processImages"
                :disabled="isProcessing || !files.some(f => f.status === 'pending')"
                class="bg-red-500 text-white px-8 py-3 rounded-xl font-bangers text-2xl tracking-wide border-4 border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[2px] hover:translate-y-[2px] hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] active:translate-x-[6px] active:translate-y-[6px] active:shadow-none transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-x-0 disabled:hover:translate-y-0 disabled:hover:shadow-[6px_6px_0px_0px_rgba(0,0,0,1)]"
              >
                <span v-if="isProcessing" class="flex items-center gap-2">
                  <svg class="animate-spin h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  SMASHING...
                </span>
                <span v-else>SMASH ALL!</span>
              </button>
            </div>
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
                        <span class="font-black text-black text-sm font-bangers tracking-wide">{{ (fileItem.file.name.split('.').pop() || '').toUpperCase() }}</span>
                      </div>
                      <div class="text-black text-[10px] font-bold">
                        {{ formatSize(fileItem.result.resizedOriginalSize || 0) }}
                      </div>
                    </div>
                             <a :href="`${apiBase}${fileItem.result.resizedOriginal}`" target="_blank" download class="px-2 py-3 hover:bg-red-300 text-black transition-colors flex items-center justify-center bg-white">
                      <!-- SVG Download Icon -->
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
                        <span class="bg-black text-white text-[10px] font-bold px-1 py-0.5 rounded">
                          -{{ calculateSavings(fileItem.result.originalSize, fileItem.result.avifSize) }}%
                        </span>
                      </div>
                      <div class="text-black text-[10px] font-bold">
                        {{ formatSize(fileItem.result.avifSize) }}
                      </div>
                    </div>
                    <a :href="`${apiBase}${fileItem.result.avif}`" target="_blank" download class="px-2 py-3 hover:bg-green-300 text-black transition-colors flex items-center justify-center bg-white">
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
                        <span class="bg-black text-white text-[10px] font-bold px-1 py-0.5 rounded">
                          -{{ calculateSavings(fileItem.result.originalSize, fileItem.result.webpSize) }}%
                        </span>
                      </div>
                      <div class="text-black text-[10px] font-bold">
                        {{ formatSize(fileItem.result.webpSize) }}
                      </div>
                    </div>
                    <a :href="`${apiBase}${fileItem.result.webp}`" target="_blank" download class="px-2 py-3 hover:bg-blue-300 text-black transition-colors flex items-center justify-center bg-white">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-5 h-5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M12 12.75l-3 3m0 0l-3-3m3 3V3" />
                        </svg>
                    </a>
                  </div>

                  <!-- Code Button -->
                  <button 
                    @click="copyToClipboard(getSnippet(fileItem.file.name))"
                    class="w-10 h-10 bg-black text-white rounded-lg flex items-center justify-center hover:bg-gray-800 hover:scale-105 transition-all shadow-[2px_2px_0px_0px_rgba(100,100,100,1)] border-2 border-transparent group/code relative"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-5 h-5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 18" />
                    </svg>
                    <!-- Tooltip -->
                    <div class="absolute bottom-full mb-2 left-1/2 -translate-x-1/2 w-48 bg-white border-2 border-black p-2 rounded hidden group-hover/code:block shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] z-10 text-center">
                      <p class="font-bangers text-black text-lg leading-none mb-1">COPY HTML</p>
                      <p class="font-outfit text-black text-xs font-bold leading-tight">Copy the &lt;picture&gt; tag snippet for this image.</p>
                    </div>
                  </button>

                  <!-- LQIP Button -->
                  <button 
                    @click="copyToClipboard(fileItem.result.lqip)"
                    class="w-10 h-10 bg-purple-400 text-black rounded-lg flex items-center justify-center hover:bg-purple-300 hover:scale-105 transition-all shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] border-2 border-black group/lqip relative"
                  >
                    <span class="font-bangers text-xs">LQIP</span>
                    <!-- Tooltip Preview -->
                    <div class="absolute bottom-full mb-2 left-1/2 -translate-x-1/2 w-64 bg-white border-2 border-black p-2 rounded hidden group-hover/lqip:block shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] z-10 text-center">
                      <p class="font-bangers text-black text-lg leading-none mb-2">Low-Quality Image Placeholders</p>
                      <div class="w-24 h-auto mx-auto border-2 border-black mb-2">
                        <img :src="fileItem.result.lqip" class="w-full h-auto block" />
                      </div>
                      <p class="font-outfit text-black text-xs font-bold leading-tight">Clicking it copies the tiny blurred base64 string to your clipboard</p>
                    </div>
                  </button>

                  <!-- Preview Button -->
                  <button 
                    @click="openPreviewModal(fileItem)"
                    class="w-10 h-10 bg-yellow-400 text-black rounded-lg flex items-center justify-center hover:bg-yellow-300 hover:scale-105 transition-all shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] border-2 border-black group/preview relative"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" class="w-6 h-6">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    <!-- Tooltip -->
                    <div class="absolute bottom-full mb-2 right-0 w-48 bg-white border-2 border-black p-2 rounded hidden group-hover/preview:block shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] z-10 text-center">
                      <p class="font-bangers text-black text-lg leading-none mb-1">PREVIEW</p>
                      <p class="font-outfit text-black text-xs font-bold leading-tight">Compare the original image with the processed version.</p>
                    </div>
                  </button>
                </template>
              </div>

            </div>
          </div>
        </div>

        <!-- AUDIO LIST (Matches Image List Style) -->
        <div v-if="activeMode === 'audio' && audioFiles.length > 0" class="mt-12 space-y-6 animate-fade-in">
           <!-- Controls -->
           <div class="flex items-center justify-between border-b-2 border-dashed border-black pb-8">
              <h2 class="text-3xl font-bangers text-black tracking-wide">
                 AUDIO 
                 <span class="ml-2 text-xl font-outfit font-bold" :class="audioFiles.length >= 50 ? 'text-red-600' : 'text-green-600'">
                    ({{ audioFiles.length }} / 50)
                 </span>
              </h2>
              <div class="flex gap-4">
                 <button 
                  v-if="audioFiles.some(f => f.status === 'done')"
                  @click="downloadAll"
                  :disabled="isDownloading"
                  class="bg-blue-500 text-white px-8 py-3 rounded-xl font-bangers text-2xl tracking-wide border-4 border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[2px] hover:translate-y-[2px] hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] active:translate-x-[6px] active:translate-y-[6px] active:shadow-none transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-x-0 disabled:hover:translate-y-0 disabled:hover:shadow-[6px_6px_0px_0px_rgba(0,0,0,1)]"
                >
                  <span v-if="isDownloading" class="flex items-center gap-2">
                    <svg class="animate-spin h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    ZIPPING...
                  </span>
                  <span v-else>DOWNLOAD ZIP</span>
                </button>

                 <button 
                   @click="processAudio"
                   :disabled="isProcessing || !audioFiles.some(f => f.status === 'pending')"
                   class="bg-green-500 text-white px-8 py-3 rounded-xl font-bangers text-2xl tracking-wide border-4 border-black shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[2px] hover:translate-y-[2px] hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] active:translate-x-[6px] active:translate-y-[6px] active:shadow-none transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-x-0 disabled:hover:translate-y-0 disabled:hover:shadow-[6px_6px_0px_0px_rgba(0,0,0,1)]"
                 >
                   {{ isProcessing ? 'CONVERTING...' : 'CONVERT ALL!' }}
                 </button>
               </div>
            </div>

            <!-- Audio File List -->
            <div class="grid gap-4">
               <div v-for="fileItem in audioFiles" :key="fileItem.id" class="bg-white border-4 border-black rounded-xl p-4 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] flex items-center justify-between">
                  <div class="flex items-center gap-4 border-r-2 border-black border-dashed pr-4 w-2/5">
                     <div class="w-14 h-14 bg-green-200 border-2 border-black rounded-lg flex items-center justify-center text-2xl shrink-0 shadow-[1px_1px_0px_0px_rgba(0,0,0,1)]">🎵</div>
                     <div class="min-w-0">
                        <div class="font-bold truncate text-black text-lg font-bangers tracking-wide">{{ fileItem.file.name }}</div>
                        <div class="flex items-center gap-2">
                           <div class="text-black font-bold text-sm bg-gray-100 inline-block px-2 border-2 border-black rounded">{{ formatSize(fileItem.file.size) }}</div>
                           <button 
                             v-if="!fileItem.audioResult && fileItem.status !== 'processing'"
                             @click="openAudioConfigModal(fileItem)"
                             class="text-white font-bold text-sm bg-purple-500 inline-block px-2 border-2 border-black rounded ml-2 cursor-pointer hover:bg-purple-600 transition-colors"
                           >
                             Configure
                           </button>
                        </div>
                     </div>
                  </div>

                  <!-- Status/Result -->
                  <div class="w-3/5 flex items-center justify-end gap-3 pl-4">
                    <div v-if="fileItem.status !== 'done'" class="flex-1 flex justify-end font-bangers">
                       <span v-if="fileItem.status === 'pending'" class="px-4 py-1 rounded-lg font-bold uppercase bg-yellow-200 text-black border-2 border-black">READY</span>
                       <span v-else-if="fileItem.status === 'processing'" class="px-4 py-1 rounded-lg font-bold uppercase bg-orange-200 text-black border-2 border-black animate-pulse">...</span>
                     </div>
                     <template v-else-if="fileItem.audioResult">
                        <!-- MP3 Result -->
                        <div class="flex items-center bg-orange-100 rounded-lg border-2 border-black bg-orange-200 overflow-hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] hover:translate-y-[-1px] transition-transform">
                          <div class="px-3 py-1 flex flex-col justify-center border-r-2 border-black bg-orange-200">
                             <div class="flex items-center gap-1.5">
                                <span class="font-black text-black text-sm font-bangers tracking-wide">MP3</span>
                                <span class="bg-black text-white text-[10px] font-bold px-1 py-0.5 rounded">
                                   {{ formatSize(fileItem.audioResult.mp3Size) }}
                                </span>
                             </div>
                          </div>
                          <a :href="`${apiBase}${fileItem.audioResult.mp3}`" download class="px-2 py-3 hover:bg-orange-300 text-black transition-colors flex items-center justify-center bg-white">
                             <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-5 h-5">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M12 12.75l-3 3m0 0l-3-3m3 3V3" />
                             </svg>
                          </a>
                        </div>
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

    <!-- Audio Config Modal -->
    <div v-if="showAudioConfigModal" class="fixed inset-0 bg-black/50 z-[100] flex items-center justify-center backdrop-blur-sm p-4">
      <div class="bg-white border-4 border-black shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] rounded-xl w-full max-w-md overflow-hidden relative">
        <div class="bg-purple-400 border-b-4 border-black p-4 flex justify-between items-center">
          <h3 class="font-bangers text-2xl tracking-wide text-white drop-shadow-md">CONFIGURE AUDIO</h3>
          <button @click="closeAudioConfigModal" class="hover:bg-purple-500 rounded p-1 text-white">
             <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-6 h-6">
               <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
             </svg>
          </button>
        </div>
        <div class="p-6 space-y-6">
           <!-- Bitrate -->
           <div class="space-y-2">
              <label class="font-bold text-lg">Bitrate</label>
              <div class="flex gap-2">
                 <button 
                   v-for="bitrate in ['128k', '192k', '320k']" 
                   :key="bitrate"
                   @click="audioOptions.bitrate = bitrate"
                   class="flex-1 py-2 border-2 border-black rounded-lg font-bold transition-all"
                   :class="audioOptions.bitrate === bitrate ? 'bg-black text-white' : 'bg-white hover:bg-gray-100'"
                 >
                   {{ bitrate }}
                 </button>
              </div>
           </div>
           
           <!-- Channels -->
           <div class="space-y-2">
              <label class="font-bold text-lg">Channels</label>
              <div class="flex gap-2">
                 <button 
                   @click="audioOptions.channels = 'stereo'"
                   class="flex-1 py-2 border-2 border-black rounded-lg font-bold transition-all"
                   :class="audioOptions.channels === 'stereo' ? 'bg-black text-white' : 'bg-white hover:bg-gray-100'"
                 >
                   Stereo
                 </button>
                 <button 
                   @click="audioOptions.channels = 'mono'"
                   class="flex-1 py-2 border-2 border-black rounded-lg font-bold transition-all"
                   :class="audioOptions.channels === 'mono' ? 'bg-black text-white' : 'bg-white hover:bg-gray-100'"
                 >
                   Mono
                 </button>
              </div>
           </div>

            <!-- Speed -->
            <div class="space-y-2">
              <div class="flex justify-between">
                <label class="font-bold text-lg">Speed</label>
                <span class="font-mono font-bold">{{ audioOptions.speed }}x</span>
              </div>
              <input 
                v-model.number="audioOptions.speed" 
                type="range" 
                min="0.5" 
                max="1.5" 
                step="0.1"
                class="w-full accent-black h-4 bg-gray-200 rounded-lg appearance-none cursor-pointer border-2 border-black"
              />
              <div class="flex justify-between text-xs font-bold text-gray-500 font-mono">
                <span>0.5x</span>
                <span>1.0x</span>
                <span>1.5x</span>
              </div>
           </div>
        </div>
        <div class="border-t-4 border-black p-4 bg-gray-50 flex justify-end gap-3">
           <button 
             @click="closeAudioConfigModal"
             class="px-6 py-2 font-bold border-2 border-black rounded-lg hover:bg-gray-200"
           >
             CANCEL
           </button>
           <button 
             @click="saveAudioConfig"
             class="px-6 py-2 font-bold bg-green-400 border-2 border-black rounded-lg shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] hover:translate-y-[-1px] hover:bg-green-500 hover:shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] transition-all"
           >
             SAVE CHANGES
           </button>
        </div>
      </div>
    </div>

    <!-- Preview Modal -->
    <div v-if="showPreviewModal" class="fixed inset-0 bg-black/80 flex items-center justify-center z-50 backdrop-blur-sm p-8" @click.self="closePreviewModal">
      <div class="bg-white border-4 border-black rounded-2xl shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] max-w-6xl w-full h-[90vh] flex flex-col overflow-hidden">
        
        <!-- Header -->
        <div class="p-6 border-b-4 border-black flex items-center justify-between bg-yellow-50">
          <h3 class="text-3xl font-bangers text-black">PREVIEW</h3>
          
          <div class="flex gap-4">
            <button 
              @click="previewFormat = 'avif'"
              :class="[previewFormat === 'avif' ? 'bg-green-400 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] translate-x-[1px] translate-y-[1px]' : 'bg-white shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:bg-green-100']"
              class="px-4 py-2 border-2 border-black rounded-lg font-bold transition-all font-bangers text-xl"
            >
              AVIF
            </button>
            <button 
              @click="previewFormat = 'webp'"
              :class="[previewFormat === 'webp' ? 'bg-blue-400 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] translate-x-[1px] translate-y-[1px]' : 'bg-white shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:bg-blue-100']"
              class="px-4 py-2 border-2 border-black rounded-lg font-bold transition-all font-bangers text-xl"
            >
              WEBP
            </button>
            <button 
              v-if="previewFile?.result?.resizedOriginal"
              @click="previewFormat = 'resized'"
              :class="[previewFormat === 'resized' ? 'bg-red-400 shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] translate-x-[1px] translate-y-[1px]' : 'bg-white shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:bg-red-100']"
              class="px-4 py-2 border-2 border-black rounded-lg font-bold transition-all font-bangers text-xl"
            >
              RESIZED {{ previewFile.file.name.split('.').pop()?.toUpperCase() }}
            </button>
          </div>

          <button @click="closePreviewModal" class="text-black hover:text-red-500 transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="3" stroke="currentColor" class="w-8 h-8">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Comparison View -->
        <div class="flex-1 relative bg-[url('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAMUlEQVQ4T2NkYGAQYcAP3uCTZhw1gGGYhAGBZIA/nYDCgBDAm9BGDWAAJyRCgLaBCAAgXwixzAS0pgAAAABJRU5ErkJggg==')] overflow-hidden flex items-center justify-center p-4">
          
          <div class="relative inline-block max-h-full">
             <!-- Bottom Image (Processed - After) -->
             <img 
              :src="getPreviewUrl()" 
              class="max-w-full max-h-[calc(90vh-150px)] block select-none" 
              draggable="false"
            />
            
            <!-- Top Image (Original - Before) - Clipped -->
            <div 
              class="absolute top-0 left-0 h-full overflow-hidden border-r-4 border-white shadow-[5px_0_10px_rgba(0,0,0,0.3)]"
              :style="{ width: `${sliderPosition}%` }"
            >
              <img 
                :src="previewOriginalUrl" 
                class="max-w-none h-full block select-none" 
                :style="{ width: 'auto', height: '100%', objectFit: 'contain' }" 
                draggable="false"
              />
            </div>

            <!-- Slider Handle (Invisible input) -->
            <input 
              type="range" 
              min="0" 
              max="100" 
              v-model.number="sliderPosition"
              class="absolute inset-0 w-full h-full opacity-0 cursor-ew-resize z-10 m-0 p-0"
            />
            
            <!-- Labels -->
            <div class="absolute bottom-4 left-4 bg-black/50 text-white px-2 py-1 rounded font-bold pointer-events-none">BEFORE</div>
            <div class="absolute bottom-4 right-4 bg-black/50 text-white px-2 py-1 rounded font-bold pointer-events-none">AFTER</div>

          </div>

        </div>

      </div>
    </div>

  </div>
</template>

<style>
/* Custom styles if needed */
</style>
