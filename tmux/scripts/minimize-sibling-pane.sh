#!/bin/sh

MIN_ROWS=5

win_id="$(tmux display-message -p '#{window_id}')"
cur_id="$(tmux display-message -p '#{pane_id}')"

cur_left="$(tmux display-message -p '#{pane_left}')"
cur_width="$(tmux display-message -p '#{pane_width}')"

panes="$(tmux list-panes -t "$win_id" -F '#{pane_id} #{pane_left} #{pane_width} #{pane_top} #{pane_height}' \
  | awk -v L="$cur_left" -v W="$cur_width" '$2==L && $3==W {print $1, $4, $5}')"

count="$(printf "%s\n" "$panes" | grep -c '^[^ ]')"
[ "$count" -lt 2 ] && exit 0

other_count=$((count - 1))
total_height="$(printf "%s\n" "$panes" | awk '{sum += $3} END {print sum}')"
target_height=$((total_height - other_count * MIN_ROWS))

tmux resize-pane -t "$cur_id" -y "$target_height" >/dev/null 2>&1

printf "%s\n" "$panes" |
  awk -v C="$cur_id" '$1!=C {print $1}' |
  while IFS= read -r other_id; do
    [ -n "$other_id" ] || continue
    tmux resize-pane -t "$other_id" -y "$MIN_ROWS" >/dev/null 2>&1
  done

exit 0
