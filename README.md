# Simple Backup
This is a simple yet powerful PowerShell script for copying files. It is intended for simple, local backups on Windows systems where built-in tools are insufficient (e.g., robocopy lacking regular expressions support).

### Features
- Copies all files, including locked ones, using Windows Volume Shadow Copy Service (VSS)
- Supports file exclusion using full-path regular expressions
- Preserves file security descriptors and attributes
- Skips reparse points (e.g., symlinks, directory junctions)

### Usage
Set the required variables in the script and run it with administrative privileges. 
`> pwsh .\backup.ps1`

### Requirements
- at least version 7.0 of PowerShell

### Limitations
- last access time and last write time are not preserved
- performance may degrade for large volumes of files

### License
Licensed under the Apache License 2.0. See the LICENSE.txt file for details.

---
Disclaimer of Warranty. Unless required by applicable law or agreed to in writing, Licensor provides the Work (and each Contributor provides its Contributions) on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied, including, without limitation, any warranties or conditions of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR PURPOSE. You are solely responsible for determining the appropriateness of using or redistributing the Work and assume any risks associated with Your exercise of permissions under this License.
