import numpy as np
import matplotlib.pyplot as plt
from PIL import Image, ImageDraw, ImageFont
import argparse

def load_pfm(file_path):
    """Loads a PFM (Portable Float Map) file and returns a NumPy array."""
    with open(file_path, "rb") as f:
        header = f.readline().decode().strip()
        if header != "PF":
            raise ValueError("Only RGB PFM images are supported.")

        dims = list(map(int, f.readline().decode().strip().split()))
        scale = float(f.readline().decode().strip())

        endian = "<" if scale < 0 else ">"
        data = np.fromfile(f, endian + "f").reshape((dims[1], dims[0], 3))
        data = np.flipud(data)  # PFM stores images upside down
        
        return np.clip(data, 0, 1)  # Ensure values are in [0,1]

def create_comparison(image1, image2, label1="ReSTIR", label2="RIS", angle=20, title=None):
    """Creates a comparison image with a diagonal transition."""
    h, w, _ = image1.shape

    # Create a diagonal mask
    mask = np.zeros((h, w))
    slope = np.tan(np.radians(angle))  # Convert degrees to slope
    for y in range(h):
        x_cutoff = int((y - h // 2) * slope + w // 2)  # Line equation
        mask[y, :x_cutoff] = 1  # Left side uses image1

        # Add fine white line at the boundary
        if 0 <= x_cutoff < w:
            image1[y, x_cutoff] = [1, 1, 1]  # White line
            image2[y, x_cutoff] = [1, 1, 1]  # White line

    # Expand mask to RGB channels
    mask = np.repeat(mask[:, :, np.newaxis], 3, axis=2)

    # Blend the images based on the mask
    blended = image1 * mask + image2 * (1 - mask)

    # Convert to 8-bit for labeling
    blended_uint8 = (blended * 255).astype(np.uint8)
    image_with_labels = Image.fromarray(blended_uint8)
    
    # Draw labels
    draw = ImageDraw.Draw(image_with_labels)
    try:
        font = ImageFont.truetype("arial.ttf", 24)  # Try loading a font
    except:
        font = ImageFont.load_default()  # Fallback font

    draw.text((10, 10), label1, fill="white", font=font)  # Left label
    draw.text((w - 150, 10), label2, fill="white", font=font)  # Right label

    # Draw title if provided
    if title:
        text_width, text_height = draw.textbbox((0, 0), title, font=font)[2:]
        draw.text(((w - text_width) / 2, h - text_height - 10), title, fill="white", font=font)

    return image_with_labels

def create_three_image_comparison(image1, image2, image3, label1="Image 1", label2="Image 2", label3="Image 3", angle=20, title=None):
    """Creates a comparison image with three images side by side."""
    h, w, _ = image1.shape

    # Create masks for each third of the image
    mask1 = np.zeros((h, w))
    mask2 = np.zeros((h, w))
    mask3 = np.zeros((h, w))

    third_w = w // 3
    slope = np.tan(np.radians(angle))  # Convert degrees to slope
    for y in range(h):
        x_cutoff1 = int((y - h // 2) * slope + third_w)  # Line equation for first separation
        x_cutoff2 = int((y - h // 2) * slope + 2 * third_w)  # Line equation for second separation
        
        mask1[y, :x_cutoff1] = 1  # Left side uses image1
        mask2[y, x_cutoff1:x_cutoff2] = 1  # Middle side uses image2
        mask3[y, x_cutoff2:] = 1  # Right side uses image3

        # Add fine white line at the boundaries
        if 0 <= x_cutoff1 < w:
            image1[y, x_cutoff1] = [1, 1, 1]  # White line
            image2[y, x_cutoff1] = [1, 1, 1]  # White line
        if 0 <= x_cutoff2 < w:
            image2[y, x_cutoff2] = [1, 1, 1]  # White line
            image3[y, x_cutoff2] = [1, 1, 1]  # White line

    # Expand masks to RGB channels
    mask1 = np.repeat(mask1[:, :, np.newaxis], 3, axis=2)
    mask2 = np.repeat(mask2[:, :, np.newaxis], 3, axis=2)
    mask3 = np.repeat(mask3[:, :, np.newaxis], 3, axis=2)


    # Blend the images based on the masks
    blended = image1 * mask1 + image2 * mask2 + image3 * mask3

    # Convert to 8-bit for labeling
    blended_uint8 = (blended * 255).astype(np.uint8)
    image_with_labels = Image.fromarray(blended_uint8)
    
    # Draw labels
    draw = ImageDraw.Draw(image_with_labels)
    try:
        font = ImageFont.truetype("arial.ttf", 24)  # Try loading a font
    except:
        font = ImageFont.load_default()  # Fallback font

    draw.text((10, 10), label1, fill="white", font=font)  # Left label
    draw.text((third_w + 10, 10), label2, fill="white", font=font)  # Middle label
    draw.text((2*third_w + 10, 10), label3, fill="white", font=font)  # Right label

    # Draw title if provided
    if title:
        text_width, text_height = draw.textbbox((0, 0), title, font=font)[2:]
        draw.text(((w - text_width) / 2, h - text_height - 10), title, fill="white", font=font)

    return image_with_labels

def display_and_save_comparison(image_paths, output_path, labels=None, title=None, no_preview=False, angle=20):
    """Loads two or three PFM images, creates a side-by-side comparison, and saves as PNG."""
    images = [load_pfm(path) for path in image_paths]

    if len(images) < 2 or len(images) > 3:
        raise ValueError("You must provide two or three images.")

    if any(img.shape != images[0].shape for img in images):
        raise ValueError("All images must have the same dimensions.")

    if len(images) == 2:
        comparison = create_comparison(images[0], images[1], label1=labels[0] if labels else "", label2=labels[1] if labels else "", angle=angle, title=title)

    if len(images) == 3:
        comparison = create_three_image_comparison(images[0], images[1], images[2], label1=labels[0] if labels else "", label2=labels[1] if labels else "", label3=labels[2] if labels else "", angle=angle, title=title)

    if title:
        plt.title(title)

    if not no_preview:
        plt.imshow(comparison)
        plt.axis("off")
        plt.show()

    comparison.save(output_path)

if __name__ == "__main__":
    import argparse
    import matplotlib.pyplot as plt

    parser = argparse.ArgumentParser(description="Compare two or three images side by side.")
    parser.add_argument("image_paths", nargs='+', help="Paths to the images to compare (2 or 3 images).")
    parser.add_argument("-o", "--output", required=True, help="Output file path for the comparison image.")
    parser.add_argument("-l", "--labels", nargs='*', help="Optional labels for the images (same number or less than image paths).")
    parser.add_argument("-t", "--title", help="Optional title for the comparison.")
    parser.add_argument("--no-preview", action="store_true", help="Flag to disable preview of the comparison.")
    parser.add_argument("-a", "--angle", type=int, default=20, help="Angle for the diagonal transition (default: 20).")

    args = parser.parse_args()

    if args.labels and len(args.labels) > len(args.image_paths):
        parser.error("Number of labels must be less than or equal to the number of image paths.")

    display_and_save_comparison(args.image_paths, output_path=args.output, labels=args.labels, title=args.title, no_preview=args.no_preview, angle=args.angle)