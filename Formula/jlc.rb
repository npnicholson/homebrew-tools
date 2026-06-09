class Jlc < Formula
  include Language::Python::Virtualenv

  desc "Fetch JLCPCB components into a KiCad library"
  homepage "https://github.com/TousstNicolas/JLC2KiCad_lib"
  url "https://github.com/TousstNicolas/JLC2KiCad_lib/archive/48d36032108d64b0f59755234681f1ce8bc98d46.tar.gz"
  sha256 "131bb02fc9bee0af0f5902f763edaa586c2227b821f2383c641fa77d9b6c0b8b"
  license "MIT"

  depends_on "python@3.12"

  resource "KicadModTree" do
    url "https://files.pythonhosted.org/packages/c0/b0/045d0ec00308130201091dcfa4a27af732b76fd92bf3408cbbc58e223d1d/KicadModTree-1.1.2.tar.gz"
    sha256 "5dd9d8f45b5e2646b0d5412111b5ed12308fb9b8ad4b32640a3ab6545fb0eca2"
  end

  resource "requests" do
    url "https://files.pythonhosted.org/packages/ac/c3/e2a2b89f2d3e2179abd6d00ebd70bff6273f37fb3e0cc209f48b39d00cbf/requests-2.34.2.tar.gz"
    sha256 "f288924cae4e29463698d6d60bc6a4da69c89185ad1e0bcc4104f584e960b9ed"
  end

  def install
    venv = virtualenv_create(libexec, Formula["python@3.12"].opt_bin/"python3.12")
    venv.pip_install resources
    venv.pip_install buildpath

    (bin/"jlc").write <<~SCRIPT
      #!/usr/bin/env bash
      # Usage:
      #   jlc C1337258 C24112 ...
      #   jlc --file parts.txt
      #
      # parts.txt: one JLCPCB part number per line (blank lines and # comments ignored).

      set -euo pipefail

      OUTPUT_DIR="JLC2KiCad_lib"
      SYMBOL_LIB="default_lib"
      FOOTPRINT_LIB="footprint"
      MODEL_DIR="packages3d"

      parts=()

      if [[ $# -eq 0 ]]; then
          echo "Error: no part numbers supplied."
          echo "Usage: jlc C1234 C5678 ..."
          echo "       jlc --file parts.txt"
          exit 1
      fi

      if [[ "$1" == "--file" ]]; then
          [[ $# -ge 2 ]] || { echo "Error: --file requires a filename argument."; exit 1; }
          file="$2"
          [[ -f "$file" ]] || { echo "Error: file not found: $file"; exit 1; }
          while IFS= read -r line || [[ -n "$line" ]]; do
              line="${line//[$'\\t\\r\\n ']}"
              [[ -z "$line" || "$line" == \\#* ]] && continue
              parts+=("$line")
          done < "$file"
      else
          parts=("$@")
      fi

      [[ ${#parts[@]} -eq 0 ]] && { echo "Error: no part numbers found."; exit 1; }

      echo "Fetching ${#parts[@]} part(s): ${parts[*]}"

      SYM_FILE="$OUTPUT_DIR/symbol/${SYMBOL_LIB}.kicad_sym"

      "#{libexec}/bin/JLC2KiCadLib" "${parts[@]}" \\
          -dir "$OUTPUT_DIR" \\
          -symbol_lib "$SYMBOL_LIB" \\
          -footprint_lib "$FOOTPRINT_LIB" \\
          -model_dir "$MODEL_DIR" \\
          --skip_existing

      sed -i '' 's/"footprint:/"jlc:/g' "$SYM_FILE"
    SCRIPT
  end

  test do
    assert_match "Error: no part numbers supplied", shell_output("#{bin}/jlc 2>&1", 1)
  end
end
