#!/usr/bin/env python3
import os
import sys
from PIL import Image

# Configuration
INPUT_DIR = "apps/parable-bloom/assets/art/vine_segments"
OUTPUT_FILE = "apps/parable-bloom/assets/art/vines_classic_spritesheet.png"

# Target cell size in the unified sheet
CELL_SIZE = 128

# The order of columns in the 7-column sheet
# 0: up, 1: down, 2: left, 3: right, 4: body, 5: corner, 6: tail
COLUMN_MAPPING = {
    'head_up': 0,
    'head_down': 1,
    'head_left': 2,
    'head_right': 3,
    'body': 4,
    'corner': 5,
    'tail': 6
}

# Rows: 0 is healthy (vine_), 1 is withered (withered_)
ROW_MAPPING = {
    'vine_': 0,
    'withered_': 1
}

def remove_background(img):
    """
    Given an image, convert white/near-white pixels to transparent.
    Uses an aggressive threshold to remove JPEG background artifacts.
    """
    img = img.convert("RGBA")
    
    # Try using flattened data first to avoid deprecation warning
    datas = img.get_flattened_data() if hasattr(img, 'get_flattened_data') else img.getdata()
    
    new_data = []
    for item in datas:
        # Check if the pixel is near-white/light gray from JPEG artifacts
        # Using a much lower threshold and checking for gray-ish color
        r, g, b, a = item
        if r > 190 and g > 190 and b > 190 and max(r,g,b) - min(r,g,b) < 30:
            new_data.append((255, 255, 255, 0)) # Fully transparent
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    return img

def crop_to_content(img):
    """
    Strictly crop the image to the bounding box of non-transparent pixels.
    """
    # getbbox() works on the alpha channel in RGBA images
    bbox = img.getbbox()
    if bbox:
        return img.crop(bbox)
    return img

# Determine native lengths for scale factor
healthy_body_length = 788
withered_body_length = 810
healthy_body_width = 219
withered_body_width = 217

def process_segment(file_path, row):
    filename = os.path.basename(file_path)
    print(f"Processing {filename}...")
    img = Image.open(file_path)
    
    # Remove background aggressively
    img = remove_background(img)
    
    # Crop to minimal bounding box
    img = crop_to_content(img)
    
    width, height = img.size
    
    # Universal scaling to ensure wood thickness matches
    # Body natively takes up EXACTLY 1 cell height (128 scaled)
    if row == 0:
        scale = CELL_SIZE / healthy_body_length
        body_thickness = healthy_body_width
    else:
        scale = CELL_SIZE / withered_body_length
        body_thickness = withered_body_width
        
    new_width = int(width * scale)
    new_height = int(height * scale)
    
    # Force the "long" dimension to be exactly CELL_SIZE to ensure gap-less connections
    # excluding corners which are handled differently.
    if 'corner' not in filename:
        if width > height:
            new_width = CELL_SIZE
        else:
            new_height = CELL_SIZE
            
    # Resize with high quality
    img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Clean up faint anti-aliasing pixels
    if hasattr(img, 'get_flattened_data'):
        final_datas = img.get_flattened_data()
    else:
        final_datas = img.getdata()
        
    cleaned_data = []
    for r, g, b, a in final_datas:
        if a < 20: 
            cleaned_data.append((255, 255, 255, 0))
        else:
            cleaned_data.append((r, g, b, a))
    img.putdata(cleaned_data)
    
    # Create an empty 128x128 transparent cell
    cell = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    
    if 'corner' in filename:
        # Exact joint centering
        # Corner connects TOP and RIGHT.
        # So native joint is at bottom-left of the bounding box!
        # X spans [0, body_thickness]
        # Y spans [height - body_thickness, height]
        
        native_cx = body_thickness / 2.0
        native_cy = height - (body_thickness / 2.0)
        
        scaled_cx = native_cx * scale
        scaled_cy = native_cy * scale
        
        # Place the image such that scaled_cx aligns with 64, and scaled_cy aligns with 64
        offset_x = int(64 - scaled_cx)
        offset_y = int(64 - scaled_cy)
    else:
        # Standard centering for bodies, heads, and tails
        offset_x = (CELL_SIZE - new_width) // 2
        offset_y = (CELL_SIZE - new_height) // 2
        
    cell.paste(img, (offset_x, offset_y))
    
    return cell

def main():
    if not os.path.isdir(INPUT_DIR):
        print(f"Error: Input directory {INPUT_DIR} not found.")
        sys.exit(1)
        
    # Create the final sprite sheet: 7 columns, 2 rows of 128x128
    sheet_width = 7 * CELL_SIZE
    sheet_height = 2 * CELL_SIZE
    spritesheet = Image.new("RGBA", (sheet_width, sheet_height), (0, 0, 0, 0))
    
    for filename in os.listdir(INPUT_DIR):
        if not (filename.endswith('.png') or filename.endswith('.jpg')):
            continue
            
        file_path = os.path.join(INPUT_DIR, filename)
        
        # Determine row mapping
        row = -1
        if filename.startswith('vine_'):
            row = 0
        elif filename.startswith('withered_'):
            row = 1
        else:
            print(f"Skipping unknown prefix: {filename}")
            continue
            
        # Determine column mapping
        col = -1
        for key, value in COLUMN_MAPPING.items():
            if key in filename:
                col = value
                break
                
        if col == -1:
            print(f"Skipping unknown column type: {filename}")
            continue
            
        # Process image
        cell_img = process_segment(file_path, row)
        
        # Paste into the right spot in spritesheet
        pos_x = col * CELL_SIZE
        pos_y = row * CELL_SIZE
        spritesheet.alpha_composite(cell_img, dest=(pos_x, pos_y))
        
    # Save the result
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    spritesheet.save(OUTPUT_FILE, "PNG")
    print(f"Saved generated spritesheet to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
