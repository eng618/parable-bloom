from PIL import Image, ImageDraw

def create_simple_spritesheet():
    W = 896
    H = 256
    CELL = 128
    THICK = 35
    HALF = THICK / 2.0
    CENTER = 64.0
    
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    def draw_head(col, row, direction):
        x_off = col * CELL
        y_off = row * CELL
        
        # Use a secondary thickness for the flare
        FLARE = THICK # total width of arrow base will be 2 * FLARE
        
        # Base stem
        if direction == 'up':
            draw.rectangle([CENTER - HALF + x_off, CENTER + y_off, CENTER + HALF + x_off, CELL + y_off], fill=(255, 255, 255, 255))
            # Arrow head
            points = [
                (CENTER - FLARE + x_off, CENTER + y_off),
                (CENTER + FLARE + x_off, CENTER + y_off),
                (CENTER + x_off, CENTER - FLARE + y_off)
            ]
            draw.polygon(points, fill=(255, 255, 255, 255))
        elif direction == 'down':
            draw.rectangle([CENTER - HALF + x_off, y_off, CENTER + HALF + x_off, CENTER + y_off], fill=(255, 255, 255, 255))
            # Arrow head
            points = [
                (CENTER - FLARE + x_off, CENTER + y_off),
                (CENTER + FLARE + x_off, CENTER + y_off),
                (CENTER + x_off, CENTER + FLARE + y_off)
            ]
            draw.polygon(points, fill=(255, 255, 255, 255))
        elif direction == 'left':
            draw.rectangle([CENTER + x_off, CENTER - HALF + y_off, CELL + x_off, CENTER + HALF + y_off], fill=(255, 255, 255, 255))
            # Arrow head
            points = [
                (CENTER + x_off, CENTER - FLARE + y_off),
                (CENTER + x_off, CENTER + FLARE + y_off),
                (CENTER - FLARE + x_off, CENTER + y_off)
            ]
            draw.polygon(points, fill=(255, 255, 255, 255))
        elif direction == 'right':
            draw.rectangle([x_off, CENTER - HALF + y_off, CENTER + x_off, CENTER + HALF + y_off], fill=(255, 255, 255, 255))
            # Arrow head
            points = [
                (CENTER + x_off, CENTER - FLARE + y_off),
                (CENTER + x_off, CENTER + FLARE + y_off),
                (CENTER + FLARE + x_off, CENTER + y_off)
            ]
            draw.polygon(points, fill=(255, 255, 255, 255))

    def draw_body(col, row):
        x_off = col * CELL
        y_off = row * CELL
        draw.rectangle([CENTER - HALF + x_off, y_off, CENTER + HALF + x_off, CELL + y_off], fill=(255, 255, 255, 255))

    def draw_corner(col, row):
        x_off = col * CELL
        y_off = row * CELL
        # Vertical part (Top to Center)
        draw.rectangle([CENTER - HALF + x_off, y_off, CENTER + HALF + x_off, CENTER + HALF + y_off], fill=(255, 255, 255, 255))
        # Horizontal part (Center to Right)
        draw.rectangle([CENTER - HALF + x_off, CENTER - HALF + y_off, CELL + x_off, CENTER + HALF + y_off], fill=(255, 255, 255, 255))

    def draw_tail(col, row):
        x_off = col * CELL
        y_off = row * CELL
        # Body part (Top to Center)
        draw.rectangle([CENTER - HALF + x_off, y_off, CENTER + HALF + x_off, CENTER + y_off], fill=(255, 255, 255, 255))
        # Rounded Tip
        draw.ellipse([CENTER - HALF + x_off, CENTER - HALF + y_off, CENTER + HALF + x_off, CENTER + HALF + y_off], fill=(255, 255, 255, 255))

    for row in range(2):
        draw_head(0, row, 'up')
        draw_head(1, row, 'down')
        draw_head(2, row, 'left')
        draw_head(3, row, 'right')
        draw_body(4, row)
        draw_corner(5, row)
        draw_tail(6, row)

    img.save("apps/parable-bloom/assets/art/vine_simple_spritesheet.png")
    print("Saved rebuilt vine_simple_spritesheet.png")

if __name__ == "__main__":
    create_simple_spritesheet()
