# Student Management System using Bash Shell Script

## Overview

This project is a Linux-based Student Management System developed for the Operating Systems Laboratory course.

The application provides a dialog-driven interface for managing student records, entering grades, and generating reports. All data is stored in local database files and processed using Bash Shell Scripting tools.

## Features

### Student Registration

* Register new students
* Validate student information
* Prevent duplicate student IDs
* Update existing student records

### Grade Management

* Enter Operating Systems grades
* Enter OS Laboratory grades
* Validate grade ranges (0-20)
* Update existing grades

### Reporting

* Operating Systems course report
* OS Laboratory report
* Individual student report
* Student grade lookup by ID

### Data Validation

* Required field validation
* Numeric student ID validation
* Grade range validation
* Duplicate record detection

## Technologies Used

* Bash Shell Script
* Linux (Ubuntu)
* Dialog
* AWK
* File Processing
* Shell Functions

## Data Storage

The project stores information using simple database files:

* students.db
* grades.db

## Running the Project

```bash
chmod +x project.sh
./project.sh
```

## Project Structure

```text
project.sh
students.db
grades.db
```

## Course

Operating Systems Laboratory

## Author

Atiyeh Jafari Ramazani
