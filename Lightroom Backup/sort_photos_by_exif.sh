#!/usr/bin/env bash
set -euo pipefail

# 사용법:
#   ./sort_photos_by_exif.sh [원본_폴더] [결과_폴더]
#
# 인자를 생략하면:
#   원본_폴더: 현재 디렉토리(.)
#   결과_폴더: 원본_폴더/sorted_by_date

SRC_DIR="${1:-.}"
DEST_DIR="${2:-"$SRC_DIR/sorted_by_date"}"

# exiftool 설치 여부 체크
if ! command -v exiftool >/dev/null 2>&1; then
  echo "exiftool 이 설치되어 있지 않습니다. 먼저 'brew install exiftool' 로 설치해 주세요." >&2
  exit 1
fi

# 결과 폴더 생성
mkdir -p "$DEST_DIR"

# 처리할 이미지 확장자 목록 (RAW 포함, ORF / ORI 추가)
IMAGE_EXTS=(
  -iname '*.jpg'
  -o -iname '*.jpeg'
  -o -iname '*.png'
  -o -iname '*.heic'
  -o -iname '*.tif'
  -o -iname '*.tiff'
  -o -iname '*.gif'
  -o -iname '*.orf'
  -o -iname '*.ORI'
  -o -iname '*.ORF'
  -o -iname '*.ori'
)

echo "원본 폴더: $SRC_DIR"
echo "결과 폴더: $DEST_DIR"
echo "이미지/RAW 파일을 날짜별로 정리합니다..."

# find로 이미지 파일 전부 순회 (공백/한글 경로 대응을 위해 -print0 사용)
find "$SRC_DIR" -type f \( "${IMAGE_EXTS[@]}" \) -print0 | while IFS= read -r -d '' file; do
  # 결과 폴더 안의 파일은 다시 스캔하지 않도록 방어
  case "$file" in
    "$DEST_DIR"/*)
      continue
      ;;
  esac

  # EXIF DateTimeOriginal 읽기 (형식: YYYY_MM_DD)
  exif_date="$(exiftool -d '%Y_%m_%d' -DateTimeOriginal -S -s "$file" 2>/dev/null || true)"

  # EXIF에 날짜가 없으면 파일의 생성일 사용 (stat 사용)
  if [[ -z "$exif_date" ]]; then
    exif_date="$(stat -f '%Sm' -t '%Y_%m_%d' "$file")"
  fi

  # 안전장치: 그래도 없으면 unknown으로
  if [[ -z "$exif_date" ]]; then
    exif_date="unknown_date"
  fi

  target_dir="$DEST_DIR/$exif_date"
  mkdir -p "$target_dir"

  echo "[$exif_date] -> $(basename "$file")"

  # --- 여기부터: 같은 이름의 XMP 파일도 같이 이동 ---

  file_dir="$(dirname "$file")"
  file_name="$(basename "$file")"
  base_noext="${file_name%.*}"

  # 같은 이름의 xmp 파일
  xmp_lower="$file_dir/$base_noext.xmp"
  xmp_upper="$file_dir/$base_noext.XMP"

  # 이미지/RAW 파일 이동
  mv -n "$file" "$target_dir"/

  # XMP 이동
  if [[ -f "$xmp_lower" ]]; then
    echo "   └ 함께 이동: $(basename "$xmp_lower")"
    mv -n "$xmp_lower" "$target_dir"/
  fi

  if [[ -f "$xmp_upper" ]]; then
    echo "   └ 함께 이동: $(basename "$xmp_upper")"
    mv -n "$xmp_upper" "$target_dir"/
  fi

done

echo "완료!"