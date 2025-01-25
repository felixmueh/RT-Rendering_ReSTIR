# Image Comparison CLI

This project provides a command-line interface (CLI) for creating side-by-side comparisons of two or three images. It allows users to specify input image paths, output file paths, optional labels, and a title, as well as a flag to disable previewing the comparison.

## Installation

To install the required dependencies, run:

```
pip install -r requirements.txt
```

## Usage

To use the image comparison CLI, run the following command:

```
python src/combine.py [OPTIONS] <image1> <image2> [<image3>]
```

### Parameters

- `<image1>`: Path to the first image file (required).
- `<image2>`: Path to the second image file (required).
- `<image3>`: Path to the third image file (optional).
- `--output <output_path>`: Specify the output file path for the comparison image (default is `comparison.png`).
- `--label1 <label>`: Optional label for the first image.
- `--label2 <label>`: Optional label for the second image.
- `--label3 <label>`: Optional label for the third image (if provided).
- `--title <title>`: Optional title for the comparison.
- `--no-preview`: Flag to disable the preview of the comparison image.
- `--help`: Show this help message and exit.

## Examples
1. Compare two images with default output:
   ```
   python src/combine.py path/to/image1.png path/to/image2.png
   ```

2. Compare three images with custom output and labels:
   ```
   python src/combine.py path/to/image1.png path/to/image2.png path/to/image3.png --output output.png --label1 "Image 1" --label2 "Image 2" --label3 "Image 3"
   ```

3. Compare two images without preview:
   ```
   python src/combine.py path/to/image1.png path/to/image2.png --no-preview
   ```


# Usage with ReSTIR
1. Run our Renderer in Assignment 4 with different sampling techniques, i.e. ReSTIR and StreamingRIS. this will generate frame captures in the captures folder at the project root.

2. combine the pfm captures using combine.py:
   ```
   python src/combine.py -o ../../captures/comparison.png -l "ReSTIR" "Streaming RIS" -t "cbox with many lights @ 1 spp" ../../captures/ReSTIR/screenshot-50.pfm ../../captures/StreamingRIS/screenshot-50.pfm -a 20
   ```
