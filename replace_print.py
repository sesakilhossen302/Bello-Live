import os
import re

lib_dir = r'c:\Users\itsta\Downloads\picture_live\picture_live\lib'

print_pattern = re.compile(r'\bprint\(')

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            if print_pattern.search(content):
                # Replace print( with debugPrint(
                new_content = print_pattern.sub('debugPrint(', content)

                # Add import if missing and if debugPrint is used
                if 'debugPrint(' in new_content and 'package:flutter/foundation.dart' not in new_content:
                    import_statement = "import 'package:flutter/foundation.dart';\n"
                    # find the first import statement and insert before it, or at top
                    import_match = re.search(r'^import ', new_content, re.MULTILINE)
                    if import_match:
                        index = import_match.start()
                        new_content = new_content[:index] + import_statement + new_content[index:]
                    else:
                        new_content = import_statement + new_content

                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f'Replaced print in {filepath}')
