# 🔨 ANVL - Image Smasher Client

**ANVL** is a web application designed to "smash" your images into highly optimized formats, in a Pop Art-styled interface. It converts standard JPG and PNG images into modern **AVIF** and **WebP** formats, significantly reducing file size while maintaining quality.  

The **Client** application is built with **Nuxt 4** and **TailwindCSS**.
The **Server** application is built with **Node.js** and **Express**.

## ✨ Features

- **Drag & Drop Interface**: Easily upload up to 50 images at once.
- **Dual Conversion**: Automatically generates both AVIF and WebP versions for every uploaded image.
- **Preview Mode**: Compare the original image with the processed version (AVIF, WebP, or Resized) using a "Before/After" slider.
- **Image Resizing**: Resize images before processing with aspect ratio lock and custom quality settings (1-100).
- **LQIP Generation**: Automatically generates a "Low-Quality Image Placeholder" (tiny blurred base64) for instant loading previews.
- **Code Snippets**: One-click copy for HTML `<picture>` tags to implement responsive images immediately.
- **Smart Compression**: Uses `sharp` (via the server) to optimize images.
- **Savings Calculator**: Instantly see how much space you've saved (e.g., "-85%").
- **Batch Download**: Download all processed images as a single ZIP file or grab them individually.
- **Pop Art Design**: A vibrant, responsive UI featuring "Bangers" and "Outfit" fonts, bold borders, and hard shadows.

## 🚀 Getting Started

### Prerequisites

- Node.js (v18+ recommended)
- The **ANVL Server** must be running on port `4000` for image processing to work.

### Installation

1. Install dependencies for the entire project (root, client, and server):
   ```bash
   npm install
   ```

### Running the Application

Start both the client and server concurrently with a single command:

```bash
npm run dev
```

- **Client**: `http://localhost:3000`
- **Server**: `http://localhost:4000`

## 📖 Usage

1. **Start the App**: Run `npm run dev` in the root directory.
2. **Upload Images**: Drag and drop your JPG/PNG files into the "DROP IT HERE!" zone.
3. **Resize (Optional)**: Click "Resize" on any image to change dimensions and quality.
4. **Smash**: Click the **"SMASH ALL IMAGES!"** button to start processing.
5. **Preview**: Click the **Eye icon** to compare the result with the original.
6. **LQIP**: Click the **LQIP button** to copy the tiny blurred placeholder code.
7. **Download**:
   - Click the **AVIF** or **WebP** pills to download individual files.
   - If resized, click the **Red Pill** to download the resized original format.
   - Click **"DOWNLOAD ALL ZIP"** to get everything at once.
8. **Implement**: Click the code icon (</>) next to an image to copy the `<picture>` tag snippet for your website.