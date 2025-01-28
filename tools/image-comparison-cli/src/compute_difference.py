import argparse
import numpy as np
from PIL import Image
import matplotlib.pyplot as plt
from utils.pfm_loader import load_pfm

def compute_difference(image1_path, image2_path):
    """Computes the pixel-wise difference between two PFM images."""
    image1 = load_pfm(image1_path)
    image2 = load_pfm(image2_path)

    if image1.shape != image2.shape:
        raise ValueError("Images must have the same dimensions for comparison.")

    mean_diff = np.mean(image1) - np.mean(image2)

    print(f"Mean difference: {mean_diff}")

    difference = np.abs(image1 - image2)
    mean_abs_diff = np.mean(difference)

    # Calculate the relative difference
    relative_diff = difference / (image1 + 1e-10)  # Avoid division by zero
    mean_rel_diff = np.mean(relative_diff)
    return difference, mean_abs_diff, mean_rel_diff

def display_and_save_difference(image1_path, image2_path, output_path, no_preview):
    difference, mean_abs_diff, mean_rel_diff = compute_difference(image1_path, image2_path)

    # Print the mean differences
    print(f"Mean Absolute Difference: {mean_abs_diff}")
    print(f"Mean Relative Difference: {mean_rel_diff}")

    if not no_preview:
        plt.imshow(difference)
        plt.axis("off")
        plt.show()

    # Save the difference image
    difference_uint8 = (difference * 255).astype(np.uint8)
    difference_image = Image.fromarray(difference_uint8)
    difference_image.save(output_path)

    

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Calculate and display the difference between two images.")
    parser.add_argument("image1", help="Path to the first image.")
    parser.add_argument("image2", help="Path to the second image.")
    parser.add_argument("-o", "--output", required=True, help="Output file path for the difference image.")
    parser.add_argument("--no-preview", action="store_true", help="Flag to disable preview of the difference image.")

    args = parser.parse_args()

    display_and_save_difference(args.image1, args.image2, args.output, args.no_preview)