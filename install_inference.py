import os
import platform
import subprocess
import sys

TT_PYPI_URL = "https://pypi.eng.aws.tenstorrent.com/simple"
TT_PPA = "ppa:tenstorrent/ppa"
TT_INFERENCE_SERVER = "tt-inference-server"
DEFAULT_MODEL_URL = "https://huggingface.co/tenstorrent/llama-2-7b/resolve/main/model.bin"
MODEL_PATH = "/opt/tenstorrent/models/llama-2-7b/model.bin"

def run(cmd, check=True):
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}")
    return result.returncode == 0

def is_ubuntu():
    return "ubuntu" in platform.platform().lower()

def has_tenstorrent_hardware():
    # Replace with actual hardware check if available
    return os.path.exists("/dev/tenstorrent")

def install_via_pip():
    try:
        run(f"pip install --extra-index-url {TT_PYPI_URL} {TT_INFERENCE_SERVER}")
        return True
    except Exception:
        return False

def install_via_ppa():
    try:
        run("sudo apt-get update")
        run(f"sudo add-apt-repository -y {TT_PPA}")
        run("sudo apt-get update")
        run(f"sudo apt-get install -y {TT_INFERENCE_SERVER}")
        return True
    except Exception:
        return False

def install_via_git():
    try:
        run("git clone https://github.com/tenstorrent/tt-inference-server.git")
        run("cd tt-inference-server && pip install .")
        return True
    except Exception:
        return False

def download_model():
    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    run(f"wget -O {MODEL_PATH} {DEFAULT_MODEL_URL}")

def main():
    print("Checking for Tenstorrent hardware...")
    if not has_tenstorrent_hardware():
        print("Warning: Tenstorrent hardware not detected. Proceeding with CPU fallback.")
    print("Attempting to install tt-inference-server via pip...")
    if install_via_pip():
        print("Installed via pip.")
    elif is_ubuntu():
        print("Attempting to install via Ubuntu PPA...")
        if install_via_ppa():
            print("Installed via PPA.")
        else:
            print("Attempting to install via git clone...")
            if install_via_git():
                print("Installed via git.")
            else:
                print("All install methods failed.")
                sys.exit(1)
    else:
        print("Attempting to install via git clone...")
        if install_via_git():
            print("Installed via git.")
        else:
            print("All install methods failed.")
            sys.exit(1)
    print("Downloading default model...")
    download_model()
    print("Setup complete.")

if __name__ == "__main__":
    main()