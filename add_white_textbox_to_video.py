"""
Batch White Text Box Overlay for Videos

This script adds a white text box at the top of videos (viral Instagram trend).
The white box appears at the top of the video with customizable text.

Features:
- Batch processing of multiple videos
- Customizable text content, font, size, and colors
- Adjustable box height and padding
- Supports various video formats
- Uses FFmpeg for video processing
- Follows the established utility script pattern

Requirements:
    - FFmpeg installed on the system
"""

import os
import subprocess
import sys
from glob import glob
import platform
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)

# ===== SYSTEM DETECTION =====
def detect_system():
    """Detect the operating system."""
    system = platform.system().lower()
    is_windows = system == "windows"
    is_linux = system == "linux"
    is_macos = system == "darwin"
    
    logger.info(f"Detected OS: {platform.system()} ({platform.release()})")
    ffmpeg_path = detect_ffmpeg()
    return {
        'is_windows': is_windows,
        'is_linux': is_linux,
        'is_macos': is_macos,
        'ffmpeg_path': ffmpeg_path,
        'path_separator': '\\' if is_windows else '/'
    }

def detect_ffmpeg():
    """Auto-detect FFmpeg installation."""
    common_paths = [
        "ffmpeg",
        "/usr/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/opt/homebrew/bin/ffmpeg",
        "C:\\ffmpeg\\bin\\ffmpeg.exe",
        "C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe",
    ]
    
    for path in common_paths:
        try:
            result = subprocess.run([path, "-version"], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                logger.info(f"Found FFmpeg at: {path}")
                return path
        except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
            continue
    
    logger.warning("FFmpeg not found. Please install FFmpeg.")
    return "ffmpeg"

# ===== CONFIGURATION =====
SYSTEM_INFO = detect_system()

# Input/Output paths (single set, keep it simple)
INPUT_PATH = "/home/trexx/D_Drive/IgAssets/cumattozze"              # File or directory containing videos
OUTPUT_DIR = "/home/trexx/D_Drive/IgAssets/cumattozze/textbox"               # Output directory

BATCH_MODE = True  # True for batch processing, False for single file

# ===== TEXT BOX SETTINGS =====
TEXT_CONTENT = "........."                    # Text to display in the white box
FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"  # Path to font file (Linux default)
# For Windows, use: "C:\\Windows\\Fonts\\arial.ttf"
# For macOS, use: "/System/Library/Fonts/Helvetica.ttc"

FONT_SIZE = 40                                      # Font size in pixels
FONT_COLOR = "black"                                # Text color (black, white, red, etc.)
BOX_COLOR = "white"                                 # Background box color
BOX_HEIGHT = 50                                   # Height of the white box in pixels
BOX_OPACITY = 1.0                                   # Box opacity (0.0 to 1.0, where 1.0 is fully opaque)
TEXT_PADDING_TOP = 20                               # Padding from top of box to text

# ===== VIDEO SETTINGS =====
VIDEO_EXTS = [".mp4", ".mov", ".mkv", ".avi", ".webm"]
VIDEO_CODEC = "libx264"                             # Video codec
VIDEO_PRESET = "medium"                             # Encoding preset (ultrafast, fast, medium, slow, slower)
VIDEO_CRF = 23                                      # Quality (lower = better, 18-28 recommended)

# Output resolution (set to None to keep original size + box height)
OUTPUT_WIDTH = 1080                                 # Output width in pixels
OUTPUT_HEIGHT = 1920                                # Output height in pixels

FFMPEG_PATH = SYSTEM_INFO['ffmpeg_path']

# ========== HELPER FUNCTIONS ==========

def find_files(path, exts):
    """Find files with specified extensions in a path (file or directory)."""
    if os.path.isfile(path):
        return [path]
    files = []
    for ext in exts:
        files.extend(glob(os.path.join(path, f"*{ext}")))
        files.extend(glob(os.path.join(path, f"*{ext.upper()}")))
    return list(set(files))  # Remove duplicates

def get_video_info(input_path):
    """Get video dimensions using ffprobe."""
    try:
        ffprobe_path = FFMPEG_PATH.replace('ffmpeg', 'ffprobe')
        cmd = [
            ffprobe_path,
            '-v', 'error',
            '-select_streams', 'v:0',
            '-show_entries', 'stream=width,height',
            '-of', 'csv=s=x:p=0',
            input_path
        ]
        output = subprocess.check_output(cmd).decode().strip()
        width, height = map(int, output.split('x'))
        return width, height
    except Exception as e:
        logger.error(f"Error getting video info: {str(e)}")
        return None, None

def hex_to_rgb(color_name):
    """Convert color name to RGB hex for FFmpeg."""
    colors = {
        'white': '0xFFFFFF',
        'black': '0x000000',
        'red': '0xFF0000',
        'green': '0x00FF00',
        'blue': '0x0000FF',
        'yellow': '0xFFFF00',
        'gray': '0x808080',
        'grey': '0x808080',
    }
    return colors.get(color_name.lower(), '0xFFFFFF')

# ========== VIDEO PROCESSING FUNCTIONS ==========

def add_textbox_to_video(input_path, output_path):
    """Add white text box ABOVE the video (no overlap) by padding the canvas and drawing text in the padded area."""
    try:
        # Get video dimensions
        width, height = get_video_info(input_path)
        if not width or not height:
            logger.error(f"Could not get video dimensions for {os.path.basename(input_path)}")
            return False

        # New canvas height (video + box on top)
        new_height = height + BOX_HEIGHT

        # Text position inside the white box (centered horizontally)
        text_x = "(w-text_w)/2"
        text_y = f"{TEXT_PADDING_TOP}"

        # Colors
        box_color_hex = hex_to_rgb(BOX_COLOR)

        # Escape text for FFmpeg
        escaped_text = TEXT_CONTENT.replace("'", "'\\'" )

        # Filter steps:
        # 1) Pad: increase height, shift video down by BOX_HEIGHT, fill pad color as the box color
        # 2) Optional drawbox to ensure top region is solid (useful if pad color not applied on some builds)
        # 3) Drawtext in the padded area
        # 4) Scale to output resolution if specified
        filter_parts = []
        filter_parts.append(
            f"pad=w={width}:h={new_height}:x=0:y={BOX_HEIGHT}:color={box_color_hex}@{BOX_OPACITY}"
        )
        filter_parts.append(
            f"drawbox=x=0:y=0:w={width}:h={BOX_HEIGHT}:color={box_color_hex}@{BOX_OPACITY}:t=fill"
        )
        filter_parts.append(
            f"drawtext=text='{escaped_text}':"
            f"fontfile={FONT_PATH}:"
            f"fontsize={FONT_SIZE}:"
            f"fontcolor={FONT_COLOR}:"
            f"x={text_x}:y={text_y}"
        )
        
        # Add scaling filter if output resolution is specified
        if OUTPUT_WIDTH and OUTPUT_HEIGHT:
            filter_parts.append(
                f"scale={OUTPUT_WIDTH}:{OUTPUT_HEIGHT}:force_original_aspect_ratio=decrease,"
                f"pad={OUTPUT_WIDTH}:{OUTPUT_HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black"
            )

        vf_filter = ",".join(filter_parts)

        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else OUTPUT_DIR, exist_ok=True)

        # FFmpeg command
        cmd = [
            FFMPEG_PATH, '-y',
            '-i', input_path,
            '-vf', vf_filter,
            '-c:v', VIDEO_CODEC,
            '-preset', VIDEO_PRESET,
            '-crf', str(VIDEO_CRF),
            '-c:a', 'copy',
            '-movflags', '+faststart',
            output_path
        ]

        logger.info(f"Processing: {os.path.basename(input_path)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            logger.info(f"✓ Successfully processed: {os.path.basename(input_path)}")
            return True
        else:
            logger.error(f"✗ FFmpeg error for {os.path.basename(input_path)}: {result.stderr}")
            return False

    except Exception as e:
        logger.error(f"✗ Error processing {os.path.basename(input_path)}: {str(e)}")
        return False

# ========== MAIN PROCESSING FUNCTIONS ==========

def process_single_file(input_path, output_dir):
    """Process a single video file."""
    base, ext = os.path.splitext(os.path.basename(input_path))
    output_file = os.path.join(output_dir, f"{base}_textbox{ext}")
    
    # Skip if output exists
    if os.path.exists(output_file):
        logger.info(f"Output already exists, skipping: {os.path.basename(output_file)}")
        return False
    
    return add_textbox_to_video(input_path, output_file)

def batch_process(input_dir, output_dir):
    """Process all video files in a directory."""
    # Find all video files
    files = find_files(input_dir, VIDEO_EXTS)
    
    # Filter out files in output directory
    files = [f for f in files if not f.startswith(os.path.abspath(output_dir))]
    
    if not files:
        logger.error(f"No video files found in {input_dir}")
        return
    
    logger.info(f"\n{'='*60}")
    logger.info(f"Found {len(files)} video(s) to process")
    logger.info(f"Text: '{TEXT_CONTENT}'")
    logger.info(f"Box height: {BOX_HEIGHT}px")
    logger.info(f"Font size: {FONT_SIZE}px")
    logger.info(f"{'='*60}\n")
    
    # Process each file
    success_count = 0
    for i, input_file in enumerate(files, 1):
        logger.info(f"\n[{i}/{len(files)}] Processing: {os.path.basename(input_file)}")
        
        if process_single_file(input_file, output_dir):
            success_count += 1
    
    # Summary
    logger.info(f"\n{'='*60}")
    logger.info(f"=== SUMMARY ===")
    logger.info(f"Total files: {len(files)}")
    logger.info(f"Successfully processed: {success_count}")
    logger.info(f"Failed: {len(files) - success_count}")
    logger.info(f"Output directory: {output_dir}")
    logger.info(f"{'='*60}")

def main():
    """Main entry point."""
    try:
        # Validate FFmpeg
        if FFMPEG_PATH == "ffmpeg":
            logger.warning("FFmpeg path not detected. Attempting to use 'ffmpeg' from PATH.")
        
        # Validate font path
        if not os.path.exists(FONT_PATH):
            logger.warning(f"Font file not found: {FONT_PATH}")
            logger.warning("Please update FONT_PATH in the configuration section.")
            logger.warning("The script will continue but may fail if FFmpeg cannot find the font.")
        
        # Create output directory
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        
        if os.path.isfile(INPUT_PATH):
            # Single file processing
            logger.info(f"Processing single file: {INPUT_PATH}")
            process_single_file(INPUT_PATH, OUTPUT_DIR)
        elif os.path.isdir(INPUT_PATH) and BATCH_MODE:
            # Batch processing
            batch_process(INPUT_PATH, OUTPUT_DIR)
        else:
            logger.error("INPUT_PATH must be a file or a directory with BATCH_MODE=True")
            logger.error(f"Current INPUT_PATH: {INPUT_PATH}")
            logger.error(f"Current BATCH_MODE: {BATCH_MODE}")
            
    except KeyboardInterrupt:
        logger.info("\n\nProcess interrupted by user.")
    except Exception as e:
        logger.error(f"Error in main process: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
