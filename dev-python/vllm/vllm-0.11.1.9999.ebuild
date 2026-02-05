# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{10..13} )

inherit distutils-r1 cuda git-r3

DESCRIPTION="A high-throughput and memory-efficient inference and serving engine for LLMs"
HOMEPAGE="https://github.com/vllm-project/vllm https://docs.vllm.ai/"
EGIT_REPO_URI="https://github.com/vllm-project/vllm.git"
EGIT_COMMIT="v0.11.1"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="cuda rocm cpu test flashinfer video audio"

# vLLM auto-detects backend from PyTorch, but you can force one
# If no backend USE flag is set, it will auto-detect from torch
REQUIRED_USE="
	cuda? ( !rocm !cpu )
	rocm? ( !cuda !cpu )
"

RDEPEND="
	>=dev-python/regex-2023.0.0[${PYTHON_USEDEP}]
	dev-python/cachetools[${PYTHON_USEDEP}]
	dev-python/psutil[${PYTHON_USEDEP}]
	dev-python/sentencepiece[${PYTHON_USEDEP}]
	dev-python/numpy[${PYTHON_USEDEP}]
	>=dev-python/requests-2.26.0[${PYTHON_USEDEP}]
	dev-python/tqdm[${PYTHON_USEDEP}]
	dev-python/blake3[${PYTHON_USEDEP}]
	dev-python/py-cpuinfo[${PYTHON_USEDEP}]
	>=dev-python/transformers-4.56.0[${PYTHON_USEDEP}]
	<dev-python/transformers-5[${PYTHON_USEDEP}]
	>=dev-python/tokenizers-0.21.1[${PYTHON_USEDEP}]
	dev-python/protobuf-python[${PYTHON_USEDEP}]
	>=dev-python/fastapi-0.115.0[${PYTHON_USEDEP}]
	dev-python/aiohttp[${PYTHON_USEDEP}]
	>=dev-python/openai-1.99.1[${PYTHON_USEDEP}]
	>=dev-python/pydantic-2.12.0[${PYTHON_USEDEP}]
	>=dev-python/prometheus-client-0.18.0[${PYTHON_USEDEP}]
	dev-python/pillow[${PYTHON_USEDEP}]
	>=dev-python/prometheus-fastapi-instrumentator-7.0.0[${PYTHON_USEDEP}]
	>=dev-python/tiktoken-0.6.0[${PYTHON_USEDEP}]
	=dev-python/lm-format-enforcer-0.11.3[${PYTHON_USEDEP}]
	>=dev-python/llguidance-1.3.0[${PYTHON_USEDEP}]
	<dev-python/llguidance-1.4.0[${PYTHON_USEDEP}]
	=dev-python/outlines-core-0.2.11[${PYTHON_USEDEP}]
	=dev-python/diskcache-5.6.3[${PYTHON_USEDEP}]
	=dev-python/lark-1.2.2[${PYTHON_USEDEP}]
	=dev-python/xgrammar-0.1.27[${PYTHON_USEDEP}]
	>=dev-python/typing-extensions-4.10[${PYTHON_USEDEP}]
	>=dev-python/filelock-3.16.1[${PYTHON_USEDEP}]
	dev-python/partial-json-parser[${PYTHON_USEDEP}]
	>=dev-python/pyzmq-25.0.0[${PYTHON_USEDEP}]
	dev-python/msgspec[${PYTHON_USEDEP}]
	>=dev-python/gguf-0.17.0[${PYTHON_USEDEP}]
	>=dev-python/mistral-common-1.8.5[${PYTHON_USEDEP}]
	>=dev-python/opencv-python-4.11.0[${PYTHON_USEDEP}]
	dev-python/pyyaml[${PYTHON_USEDEP}]
	dev-python/einops[${PYTHON_USEDEP}]
	=dev-python/compressed-tensors-0.12.2[${PYTHON_USEDEP}]
	=dev-python/depyf-0.20.0[${PYTHON_USEDEP}]
	dev-python/cloudpickle[${PYTHON_USEDEP}]
	dev-python/watchfiles[${PYTHON_USEDEP}]
	dev-python/python-json-logger[${PYTHON_USEDEP}]
	dev-python/scipy[${PYTHON_USEDEP}]
	dev-python/ninja[${PYTHON_USEDEP}]
	dev-python/pybase64[${PYTHON_USEDEP}]
	dev-python/cbor2[${PYTHON_USEDEP}]
	dev-python/ijson[${PYTHON_USEDEP}]
	dev-python/setproctitle[${PYTHON_USEDEP}]
	>=dev-python/openai-harmony-0.0.3[${PYTHON_USEDEP}]
	=dev-python/anthropic-0.71.0[${PYTHON_USEDEP}]
	>=dev-python/model-hosting-container-standards-0.1.9[${PYTHON_USEDEP}]
	<dev-python/model-hosting-container-standards-1.0.0[${PYTHON_USEDEP}]
	=sci-libs/pytorch-2.9.0[${PYTHON_USEDEP}]
	=sci-libs/torchaudio-2.9.0[${PYTHON_USEDEP}]
	=sci-libs/torchvision-0.24.0[${PYTHON_USEDEP}]
	cuda? (
		dev-python/ray[${PYTHON_USEDEP}]
		=dev-python/numba-0.61.2[${PYTHON_USEDEP}]
		flashinfer? ( =dev-python/flashinfer-python-0.5.3[${PYTHON_USEDEP}] )
	)
	rocm? (
		dev-python/ray[${PYTHON_USEDEP}]
	)
	audio? (
		dev-python/librosa[${PYTHON_USEDEP}]
		dev-python/soundfile[${PYTHON_USEDEP}]
	)
"

DEPEND="${RDEPEND}"

BDEPEND="
	>=dev-build/cmake-3.26.1
	dev-build/ninja
	>=dev-python/packaging-24.2[${PYTHON_USEDEP}]
	>=dev-python/setuptools-77.0.3[${PYTHON_USEDEP}]
	<dev-python/setuptools-81.0.0[${PYTHON_USEDEP}]
	>=dev-python/setuptools-scm-8[${PYTHON_USEDEP}]
	=sci-libs/pytorch-2.9.0[${PYTHON_USEDEP}]
	dev-python/wheel[${PYTHON_USEDEP}]
	>=dev-python/jinja-3.1.6[${PYTHON_USEDEP}]
	dev-python/regex[${PYTHON_USEDEP}]
	dev-python/build[${PYTHON_USEDEP}]
"

# Set build configuration
python_prepare_all() {
	# Set target device based on USE flags
	# If no USE flag is set, vLLM will auto-detect from PyTorch
	if use cuda; then
		export VLLM_TARGET_DEVICE="cuda"
		einfo "Building vLLM with CUDA support"
	elif use rocm; then
		export VLLM_TARGET_DEVICE="rocm"
		export ROCM_PATH="${EPREFIX}/usr"
		einfo "Building vLLM with ROCm support"
	elif use cpu; then
		export VLLM_TARGET_DEVICE="cpu"
		einfo "Building vLLM with CPU-only support"
	else
		einfo "Building vLLM with auto-detected backend from PyTorch"
	fi

	distutils-r1_python_prepare_all
}

python_configure_all() {
	# Configure build settings
	export MAX_JOBS="$(makeopts_jobs)"
	export CMAKE_BUILD_TYPE="Release"

	if use cuda; then
		# Find CUDA toolkit
		if [[ -d "/opt/cuda" ]]; then
			export CUDA_HOME="/opt/cuda"
		elif [[ -d "/usr/lib/cuda" ]]; then
			export CUDA_HOME="/usr/lib/cuda"
		fi
	fi
}

python_compile() {
	# Clean any previous builds
	rm -rf build

	distutils-r1_python_compile
}

python_install_all() {
	distutils-r1_python_install_all

	dodoc README.md
}

python_test() {
	# Tests require GPUs and are very resource-intensive
	# Skip by default
	:
}
