const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const router = require('./routes');

const app = express();
const PORT = 4000;

app.use(cors());
app.use(express.json());

// Serve static files from the 'processed' directory so the frontend can access them
app.use('/processed', express.static(path.join(__dirname, 'processed')));

app.use('/api', router);

// Ensure upload and processed directories exist
const uploadDir = path.join(__dirname, 'uploads');
const processedDir = path.join(__dirname, 'processed');

// Helper to empty a directory
const emptyDirectory = (dir) => {
    if (fs.existsSync(dir)) {
        fs.readdirSync(dir).forEach(file => {
            const curPath = path.join(dir, file);
            if (fs.lstatSync(curPath).isDirectory()) { // recurse
                 emptyDirectory(curPath);
                 fs.rmdirSync(curPath);
            } else { // delete file
                 fs.unlinkSync(curPath);
            }
        });
    }
};

// Ensure directories exist and are empty on startup
if (fs.existsSync(uploadDir)) {
    emptyDirectory(uploadDir);
} else {
    fs.mkdirSync(uploadDir);
}

if (fs.existsSync(processedDir)) {
    emptyDirectory(processedDir);
} else {
    fs.mkdirSync(processedDir);
}

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
