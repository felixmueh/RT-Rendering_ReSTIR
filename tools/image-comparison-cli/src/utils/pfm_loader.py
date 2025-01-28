import numpy as np

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