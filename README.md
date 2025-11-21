# 🔨 ANVL - Image Smasher Client

**ANVL** is a web application designed to "smash" your images into highly optimized formats, in a Pop Art-styled interface. It converts standard JPG and PNG images into modern **AVIF** and **WebP** formats, significantly reducing file size while maintaining quality.  

The **Client** application is built with **Nuxt 4** and **TailwindCSS**.
The **Server** application is built with **Node.js** and **Express**.

## ✨ Features

- **Drag & Drop Interface**: Easily upload up to 50 images at once.
- **Dual Conversion**: Automatically generates both AVIF and WebP versions for every uploaded image.
- **Smart Compression**: Uses `sharp` (via the server) to optimize images with an 80% quality preset.
- **Savings Calculator**: Instantly see how much space you've saved (e.g., "-85%").
- **Code Snippets**: One-click copy for HTML `<picture>` tags to implement responsive images immediately.
- **Batch Download**: Download all processed images as a single ZIP file or grab them individually.
- **Pop Art Design**: A vibrant, responsive UI featuring "Bangers" and "Outfit" fonts, bold borders, and hard shadows.

## 🚀 Getting Started

### Prerequisites

- Node.js (v18+ recommended)
- The **ANVL Server** must be running on port `4000` for image processing to work.

### Installation

1. Navigate to the client directory:
   ```bash
   cd client
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

### Running the Application

Start the development server:

```bash
npm run dev
```

The application will be available at `http://localhost:3000` (or `3001` if port is busy).

## 📖 Usage

1. **Start the Server**: Ensure the backend API is running (usually `npm start` in the `server` directory).
2. **Upload Images**: Drag and drop your JPG/PNG files into the "DROP IT HERE!" zone.
3. **Smash**: Click the **"SMASH ALL IMAGES!"** button to start processing.
4. **Download**:
   - Click the **AVIF** or **WebP** pills to download individual files.
   - Click **"DOWNLOAD ALL ZIP"** to get everything at once.
5. **Implement**: Click the code icon (</>) next to an image to copy the `<picture>` tag snippet for your website.