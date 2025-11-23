const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const router = express.Router();

// Configure Multer for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, path.join(__dirname, 'uploads'));
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ storage: storage });

const uploadMiddleware = upload.array('images', 50);

router.post('/process', (req, res, next) => {
    uploadMiddleware(req, res, function (err) {
        if (err instanceof multer.MulterError) {
            // A Multer error occurred when uploading.
            return res.status(400).json({ error: err.message });
        } else if (err) {
            // An unknown error occurred when uploading.
            return res.status(500).json({ error: err.message });
        }
        // Everything went fine.
        next();
    });
}, async (req, res) => {
    try {
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ error: 'No files uploaded' });
        }

        const processedImages = [];

        for (const file of req.files) {
            // Sanitize filename to prevent issues with special characters
            const parsedName = path.parse(file.originalname).name;
            const filename = parsedName.replace(/[^a-zA-Z0-9._-]/g, '_');
            const outputDir = path.join(__dirname, 'processed');
            
            // Check for resize options
            let resizeOptions = null;
            const resizeKey = `resize_${file.originalname}`;
            if (req.body[resizeKey]) {
                try {
                    resizeOptions = JSON.parse(req.body[resizeKey]);
                } catch (e) {
                    console.error('Error parsing resize options', e);
                }
            }

            // Determine quality (default 80)
            const quality = resizeOptions && resizeOptions.quality ? parseInt(resizeOptions.quality) : 80;

            // Define output paths
            const avifFilename = `${filename}.avif`;
            const webpFilename = `${filename}.webp`;
            const avifPath = path.join(outputDir, avifFilename);
            const webpPath = path.join(outputDir, webpFilename);

            // Base sharp instance
            let imagePipeline = sharp(file.path);

            // Apply resize if options exist
            if (resizeOptions) {
                imagePipeline = imagePipeline.resize({
                    width: resizeOptions.width,
                    height: resizeOptions.height,
                    fit: 'fill' // Force dimensions, aspect ratio is handled by client
                });
            }

            // Process to AVIF
            await imagePipeline
                .clone()
                .avif({ quality: quality }) 
                .toFile(avifPath);

            // Process to WebP
            await imagePipeline
                .clone()
                .webp({ quality: quality }) 
                .toFile(webpPath);

            // Get stats for generated files
            const avifStats = fs.statSync(avifPath);
            const webpStats = fs.statSync(webpPath);

            const result = {
                originalName: file.originalname,
                avif: `/processed/${avifFilename}`,
                webp: `/processed/${webpFilename}`,
                originalSize: file.size,
                avifSize: avifStats.size,
                webpSize: webpStats.size
            };

            // If resized, save the resized original format as well
            if (resizeOptions) {
                const ext = path.extname(file.originalname).toLowerCase();
                const resizedOriginalFilename = `${filename}_resized${ext}`;
                const resizedOriginalPath = path.join(outputDir, resizedOriginalFilename);

                let resizedPipeline = imagePipeline.clone();

                if (ext === '.png') {
                    // Use high compression for PNG to avoid size increase
                    // For PNG, quality isn't directly mapped like JPEG, but we can use compressionLevel
                    // However, if palette is true, we can control quantization quality.
                    // Let's stick to our optimized settings but maybe adjust if quality is very low?
                    // Sharp's png() doesn't have a direct 'quality' 1-100 param that works like JPEG unless palette is true.
                    // Let's try to map quality to palette quantization if possible, or just keep it optimized.
                    // Actually, sharp doc says: quality (Number) use the lowest number of colours needed to achieve given quality, requires palette: true.
                    resizedPipeline = resizedPipeline.png({ 
                        compressionLevel: 9, 
                        adaptiveFiltering: true, 
                        palette: true, 
                        quality: quality 
                    });
                } else if (ext === '.jpg' || ext === '.jpeg') {
                    // Use mozjpeg for better compression
                    resizedPipeline = resizedPipeline.jpeg({ 
                        quality: quality, 
                        mozjpeg: true 
                    });
                }

                await resizedPipeline.toFile(resizedOriginalPath);

                const resizedStats = fs.statSync(resizedOriginalPath);
                
                result.resizedOriginal = `/processed/${resizedOriginalFilename}`;
                result.resizedOriginalSize = resizedStats.size;
            }

            processedImages.push(result);
            
            // Optional: Delete original upload to save space? 
            // For now, let's keep it simple and maybe clean up later.
        }

        res.json({ results: processedImages });

    } catch (error) {
        console.error('Processing error:', error);
        res.status(500).json({ error: 'Image processing failed' });
    }
});

const archiver = require('archiver');

router.post('/zip', async (req, res) => {
    try {
        const { files } = req.body;

        if (!files || !Array.isArray(files) || files.length === 0) {
            return res.status(400).json({ error: 'No files specified' });
        }

        const archive = archiver('zip', {
            zlib: { level: 9 } // Sets the compression level.
        });

        res.attachment('images.zip');

        archive.pipe(res);

        files.forEach(fileUrl => {
            // fileUrl is like /processed/filename.avif
            // We need to get the absolute path
            const fileName = path.basename(fileUrl);
            const filePath = path.join(__dirname, 'processed', fileName);
            
            if (fs.existsSync(filePath)) {
                archive.file(filePath, { name: fileName });
            }
        });

        await archive.finalize();

    } catch (error) {
        console.error('Zip error:', error);
        res.status(500).json({ error: 'Zip creation failed' });
    }
});

module.exports = router;
