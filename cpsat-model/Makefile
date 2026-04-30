build-eval:
	uv sync --no-dev
	uv run nuitka \
		--clang \
		--mode=standalone \
		./src/cpsatmodel/eval_bin.py
