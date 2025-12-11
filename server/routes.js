const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegPath = require('ffmpeg-static');

// Configure ffmpeg
if (ffmpegPath) {
    ffmpeg.setFfmpegPath(ffmpegPath);
} else {
    console.warn("ffmpeg-static not found, audio conversion might fail if ffmpeg is not in PATH");
}

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

// NEW: Audio upload middleware (can reuse same logic, but maybe different field name in future? 
// For now, client sends 'images' as field name even for audio? 
// Let's stick to 'images' or 'files'. Client plan said "Dragzone" so likely 'files'.
// But wait, the client implementation plan didn't specify changing field name.
// Existing code uses 'images'. Let's support 'files' effectively by using the same middleware or a new one.
// Actually, let's keep it simple. If the client uses 'files' for audio, we need a new middleware.
// Let's assume client will update to use 'files' for audio or we can just use 'images' for everything (confusing name but works).
// Better: Generic upload middleware.
const uploadAnyMiddleware = upload.any(); 
// Wait, .any() accepts any field name.

router.post('/process-images', (req, res, next) => {
    uploadMiddleware(req, res, function (err) {
        if (err instanceof multer.MulterError) {
            return res.status(400).json({ error: err.message });
        } else if (err) {
            return res.status(500).json({ error: err.message });
        }
        next();
    });
}, async (req, res) => {
    try {
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ error: 'No files uploaded' });
        }

        const processedImages = [];

        // Parse resize options globally
        let globalResizeOptions = {};
        if (req.body.resizeOptions) {
            try {
                globalResizeOptions = JSON.parse(req.body.resizeOptions);
            } catch (e) {
                console.error('Error parsing resize options', e);
            }
        }

        for (const file of req.files) {
            // Sanitize filename
            // Fix encoding: Multer interprets headers as latin1 by default, but modern browsers send utf8
            const originalNameFixed = Buffer.from(file.originalname, 'latin1').toString('utf8');

            const parsedName = path.parse(originalNameFixed).name;
            const filename = parsedName
                .normalize('NFD')
                .replace(/[\u0300-\u036f]/g, "")
                .replace(/[^a-zA-Z0-9._-]/g, '_');
            const outputDir = path.join(__dirname, 'processed');
            
            // Check for resize options
            let resizeOptions = null;
            if (globalResizeOptions[file.originalname]) {
                resizeOptions = globalResizeOptions[file.originalname];
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
                    fit: 'fill'
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

            // Get stats
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

            // Process resized original if needed
            if (resizeOptions) {
                const ext = path.extname(file.originalname).toLowerCase();
                const resizedOriginalFilename = `${filename}_resized${ext}`;
                const resizedOriginalPath = path.join(outputDir, resizedOriginalFilename);

                let resizedPipeline = imagePipeline.clone();

                if (ext === '.png') {
                    resizedPipeline = resizedPipeline.png({ 
                        compressionLevel: 9, 
                        adaptiveFiltering: true, 
                        palette: true, 
                        quality: quality 
                    });
                } else if (ext === '.jpg' || ext === '.jpeg') {
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

            // Generate LQIP
            const lqipBuffer = await imagePipeline
                .clone()
                .resize({ width: 20, fit: 'inside' })
                .blur(1)
                .jpeg({ quality: 20, mozjpeg: true })
                .toBuffer();
            
            result.lqip = `data:image/jpeg;base64,${lqipBuffer.toString('base64')}`;

            processedImages.push(result);
        }

        res.json({ files: processedImages });

    } catch (error) {
        console.error('Processing error:', error);
        res.status(500).json({ error: 'Image processing failed' });
    }
});

router.post('/process-audio', (req, res, next) => {
    // Reuse upload middleware but maybe allow different field name?
    // Let's use uploadAnyMiddleware for maximum flexibility or just 'images' array if client sends that.
    // Client currently sends 'images' for everything. Let's assume we update client to send 'files' or still 'images'.
    // To be safe and clean, let's allow 'images' OR 'files'.
    upload.fields([{ name: 'images' }, { name: 'audio' }, { name: 'files' }])(req, res, function (err) {
         if (err instanceof multer.MulterError) {
            return res.status(400).json({ error: err.message });
        } else if (err) {
            return res.status(500).json({ error: err.message });
        }
        next();
    });
}, async (req, res) => {
    try {
        // Collect files from potential fields
        let files = [];
        if (req.files['images']) files = files.concat(req.files['images']);
        if (req.files['audio']) files = files.concat(req.files['audio']);
        if (req.files['files']) files = files.concat(req.files['files']);

        if (files.length === 0) {
            return res.status(400).json({ error: 'No audio files uploaded' });
        }

        const processedFiles = [];

        // Parse audio configs
        let audioConfigs = {};
        if (req.body.audioConfigs) {
           try {
              audioConfigs = JSON.parse(req.body.audioConfigs);
              console.log('Audio Configs Received:', JSON.stringify(audioConfigs, null, 2));
           } catch (e) {
              console.error("Error parsing audio configs", e);
           }
        }

        for (const file of files) {
             // Fix encoding
             const originalNameFixed = Buffer.from(file.originalname, 'latin1').toString('utf8');

             const parsedName = path.parse(originalNameFixed).name;
            const filename = parsedName
                .normalize('NFD')
                .replace(/[\u0300-\u036f]/g, "")
                .replace(/[^a-zA-Z0-9._-]/g, '_');
             const outputDir = path.join(__dirname, 'processed');
            const mp3Filename = `${filename}.mp3`;
            const mp3Path = path.join(outputDir, mp3Filename);

            // Get options for this file
            const options = audioConfigs[file.originalname] || {};
            console.log(`Processing ${file.originalname} with options:`, options);
            
            const bitrate = options.bitrate || '192k';
            const channels = options.channels === 'mono' ? 1 : 2;
            const speed = options.speed || 1.0;

            await new Promise((resolve, reject) => {
                let command = ffmpeg(file.path)
                    .audioBitrate(bitrate)
                    .audioChannels(channels);

                // Apply speed filter (atempo)
                if (speed !== 1.0) {
                   command = command.audioFilters(`atempo=${speed}`);
                }

                command
                    .toFormat('mp3')
                    .on('error', (err) => {
                        console.error('An error occurred: ' + err.message);
                        reject(err);
                    })
                    .on('end', () => {
                        resolve();
                    })
                    .save(mp3Path);
            });

            const mp3Stats = fs.statSync(mp3Path);

            processedFiles.push({
                originalName: file.originalname,
                mp3: `/processed/${mp3Filename}`,
                originalSize: file.size,
                mp3Size: mp3Stats.size
            });
        }

        res.json({ files: processedFiles });

    } catch (error) {
         console.error('Audio processing error:', error);
        res.status(500).json({ error: 'Audio processing failed' });
    }
});

const archiver = require('archiver');

router.post('/download-zip', async (req, res) => {
    try {
        const { files } = req.body;

        if (!files || !Array.isArray(files) || files.length === 0) {
            return res.status(400).json({ error: 'No files specified' });
        }

        const archive = archiver('zip', {
            zlib: { level: 9 }
        });

        res.attachment('images.zip');

        archive.pipe(res);

        files.forEach(fileUrl => {
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
