#!/usr/bin/env bash

STU_FILE="./students.db"
GRD_FILE="./grades.db"

TMP=$(mktemp 2>/dev/null) || { echo "Error: cannot create temp file."; exit 1; }
trap 'rm -f "$TMP"' EXIT

# ---------- Helpers ----------
require_dialog() {
  if ! command -v dialog >/dev/null 2>&1; then
    echo "Error: 'dialog' is not installed."
    echo "Install it with: sudo apt install dialog"
    exit 1
  fi
}

ensure_db_files() {
  touch "$STU_FILE" "$GRD_FILE" 2>/dev/null || {
    echo "Error: cannot create database files in this directory."
    echo "Try a writable folder."
    exit 1
  }
}

msg_error() { dialog --title "Error" --msgbox "$1" 8 60; }

is_integer() { [[ "$1" =~ ^[0-9]+$ ]]; }

is_valid_grade() {
  [[ "$1" =~ ^([0-9]|1[0-9]|20)(\.[0-9]+)?$ ]]
}

student_exists() { grep -q "^$1|" "$STU_FILE"; }
grade_exists() { grep -q "^$1|" "$GRD_FILE"; }

upsert_student() {
  local id="$1" fn="$2" ln="$3"
  awk -F'|' -v OFS='|' -v id="$id" -v fn="$fn" -v ln="$ln" '
    $1==id { $2=fn; $3=ln } { print }
  ' "$STU_FILE" > "${STU_FILE}.tmp" && mv "${STU_FILE}.tmp" "$STU_FILE"
}

upsert_grade() {
  local id="$1" os="$2" lab="$3"
  awk -F'|' -v OFS='|' -v id="$id" -v os="$os" -v lab="$lab" '
    $1==id { $2=os; $3=lab } { print }
  ' "$GRD_FILE" > "${GRD_FILE}.tmp" && mv "${GRD_FILE}.tmp" "$GRD_FILE"
}

# ---------- Register Student ----------
register_students() {
  while true; do
    dialog --clear --title "Student Registration" \
      --form "Enter student information:" 12 60 0 \
      "Student ID:"  1 1 "" 1 18 30 0 \
      "First Name:"  2 1 "" 2 18 30 0 \
      "Last Name:"   3 1 "" 3 18 30 0 \
      2> "$TMP"

    # Cancel/ESC -> back to main menu
    [ $? -ne 0 ] && return

    id=$(sed -n '1p' "$TMP" | tr -d ' ')
    fn=$(sed -n '2p' "$TMP")
    ln=$(sed -n '3p' "$TMP")

    if [ -z "$id" ] || [ -z "$fn" ] || [ -z "$ln" ]; then
      msg_error "All fields are required."
      continue
    fi

    if ! is_integer "$id"; then
      msg_error "Student ID must be numeric."
      continue
    fi

    if student_exists "$id"; then
      dialog --yesno "Student ID already exists.\nUpdate existing record?" 8 50
      if [ $? -eq 0 ]; then
        upsert_student "$id" "$fn" "$ln" || msg_error "Update failed."
      else
        continue
      fi
    else
      echo "${id}|${fn}|${ln}" >> "$STU_FILE" || { msg_error "Cannot write to $STU_FILE"; continue; }
    fi

    dialog --yesno "Do you want to register another student?" 7 50
    [ $? -ne 0 ] && return
  done
}

# ---------- Enter Grades ----------
enter_grades() {
  while true; do
    dialog --clear --title "Enter Grades" \
      --form "Enter student ID and grades:" 13 70 0 \
      "Student ID:"              1 1 "" 1 30 25 0 \
      "Operating Systems Grade:" 2 1 "" 2 30 10 0 \
      "OS Lab Grade:"            3 1 "" 3 30 10 0 \
      2> "$TMP"

    [ $? -ne 0 ] && return

    id=$(sed -n '1p' "$TMP" | tr -d ' ')
    os=$(sed -n '2p' "$TMP" | tr -d ' ')
    lab=$(sed -n '3p' "$TMP" | tr -d ' ')

    if [ -z "$id" ] || [ -z "$os" ] || [ -z "$lab" ]; then
      msg_error "All fields are required."
      continue
    fi

    if ! is_integer "$id"; then
      msg_error "Student ID must be numeric."
      continue
    fi

    if ! student_exists "$id"; then
      msg_error "This student is not registered.\nPlease register the student first."
      continue
    fi

    if ! is_valid_grade "$os" || ! is_valid_grade "$lab"; then
      msg_error "Grades must be between 0 and 20.\nDecimals allowed (e.g., 15.5)."
      continue
    fi

    if grade_exists "$id"; then
      dialog --yesno "Grades already exist for this student.\nUpdate existing grades?" 8 55
      if [ $? -eq 0 ]; then
        upsert_grade "$id" "$os" "$lab" || msg_error "Update failed."
      else
        continue
      fi
    else
      echo "${id}|${os}|${lab}" >> "$GRD_FILE" || { msg_error "Cannot write to $GRD_FILE"; continue; }
    fi

    dialog --yesno "Do you want to enter grades for another student?" 7 60
    [ $? -ne 0 ] && return
  done
}

# ---------- Reports ----------
report_os() {
  if [ ! -s "$GRD_FILE" ]; then
    dialog --title "Operating Systems Report" --msgbox "No grades data available." 7 45
    return
  fi

  output=$(
    awk -F'|' '
      NR==FNR { s[$1]=$2" "$3; next }
      { name=s[$1]; if(name=="") name="Unknown Student";
        print "ID: "$1" | Name: "name" | OS Grade: "$2
      }
    ' "$STU_FILE" "$GRD_FILE"
  )

  [ -z "$output" ] && output="No data available."
  dialog --title "Operating Systems Report" --msgbox "$output" 20 80
}

report_lab() {
  if [ ! -s "$GRD_FILE" ]; then
    dialog --title "OS Lab Report" --msgbox "No grades data available." 7 45
    return
  fi

  output=$(
    awk -F'|' '
      NR==FNR { s[$1]=$2" "$3; next }
      { name=s[$1]; if(name=="") name="Unknown Student";
        print "Name: "name" | Lab Grade: "$3
      }
    ' "$STU_FILE" "$GRD_FILE"
  )

  [ -z "$output" ] && output="No data available."
  dialog --title "OS Lab Report" --msgbox "$output" 20 70
}

report_single_student() {
  dialog --inputbox "Enter Student ID:" 8 40 2> "$TMP"
  [ $? -ne 0 ] && return

  id=$(cat "$TMP" | tr -d ' ')
  if [ -z "$id" ]; then
    msg_error "Student ID cannot be empty."
    return
  fi
  if ! is_integer "$id"; then
    msg_error "Student ID must be numeric."
    return
  fi

  name=$(awk -F'|' -v id="$id" '$1==id {print $2" "$3; exit}' "$STU_FILE")
  grades=$(awk -F'|' -v id="$id" '$1==id {print "OS Grade: "$2"\nLab Grade: "$3; exit}' "$GRD_FILE")

  [ -z "$name" ] && name="Not found"
  [ -z "$grades" ] && grades="No grades recorded."

  dialog --title "Student Report" --msgbox \
"Student ID: $id
Name: $name

$grades" 14 60
}

reports_menu() {
  while true; do
    dialog --clear --title "Reports" \
      --menu "Choose an option:" 13 60 0 \
      1 "Operating Systems Report" \
      2 "OS Lab Report" \
      3 "Single Student Report" \
      2> "$TMP"

    [ $? -ne 0 ] && return

    case "$(cat "$TMP")" in
      1) report_os ;;
      2) report_lab ;;
      3) report_single_student ;;
    esac
  done
}

# ---------- Main Menu ----------
main_menu() {
  while true; do
    dialog --clear --title "Operating Systems Project" \
      --menu "Main Menu:" 12 55 0 \
      1 "Register Student" \
      2 "Enter Grades" \
      3 "Reports" \
      2> "$TMP"

    if [ $? -ne 0 ]; then
      clear
      exit 0
    fi

    case "$(cat "$TMP")" in
      1) register_students ;;
      2) enter_grades ;;
      3) reports_menu ;;
    esac
  done
}

require_dialog
ensure_db_files
main_menu
