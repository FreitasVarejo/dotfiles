#!/bin/bash
# Funções para montar prévias de SFX. Uso: W=<pasta de trabalho> source previa.sh
# prep <entrada> <saida.wav> [fator de tom] [filtro ffmpeg]   normaliza o pico em -1 dB; 0.75 = 25% mais grave
# camada <base.wav> <fonte> <fator> <ganho dB> <sobe|desce> <saida.wav>   zumbido por baixo, crescendo ou sumindo
# monta <saida.ogg> <wav>...   toca um depois do outro, com 0,7 s de silêncio entre eles
W=${W:?defina W, a pasta de trabalho}; mkdir -p "$W"
c(){ awk "BEGIN{printf \"%.3f\", $1}"; }   # conta com zero à esquerda: o ffmpeg recusa ".7"
dur(){ ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }
prep(){
  local f=${3:-1} x=${4:-anull} t="$W/tmp_$$.wav" m
  ffmpeg -v error -y -i "$1" -af "aformat=sample_rates=44100:channel_layouts=stereo,asetrate=44100*$f,aresample=44100,$x" "$t" || return 1
  m=$(ffmpeg -i "$t" -af volumedetect -f null - 2>&1 | grep -oP 'max_volume: \K-?[0-9.]+')
  ffmpeg -v error -y -i "$t" -af "volume=$(c "-1 - ($m)")dB" "$2"; rm -f "$t"
}
camada(){
  local d fx; d=$(dur "$1")
  if [ "$5" = sobe ]; then fx="atrim=0.5:$(c "0.5+$d"),asetpts=PTS-STARTPTS,afade=in:d=$(c "$d*0.6"),afade=out:st=$(c "$d-0.15"):d=0.15"
  else fx="atrim=0.5:$(c "0.5+$d"),asetpts=PTS-STARTPTS,afade=in:d=0.03,afade=out:st=0.05:d=$(c "$d-0.05")"; fi
  prep "$2" "$W/h.wav" "$3" "$fx"
  ffmpeg -v error -y -i "$1" -i "$W/h.wav" -filter_complex "[1:a]volume=$4dB[h];[0:a][h]amix=inputs=2:duration=first:normalize=0" "$W/m.wav"
  prep "$W/m.wav" "$6" 1
}
monta(){
  local o=$1 args=() fl="" n=0 i c=""; shift
  for w in "$@"; do args+=(-i "$w"); fl+="[$n:a]apad=pad_dur=0.7[a$n];"; n=$((n+1)); done
  for i in $(seq 0 $((n-1))); do c+="[a$i]"; done
  ffmpeg -v error -y "${args[@]}" -filter_complex "${fl}${c}concat=n=$n:v=0:a=1[o]" -map "[o]" -c:a libvorbis -q:a 5 "$o"
}
