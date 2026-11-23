import os
import re
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
    tcPr.append(tcMar)

def add_formatted_text(paragraph, text):
    """Parses markdown inline tokens: **bold**, *italic*, `code`, [text](url), $\\LaTeX$"""
    pattern = re.compile(r'(\*\*.*?\*\*|\*.*?\*|`.*?`|\[.*?\]\(.*?\)|\$.*?\$|[^`\*\[\$]+)')
    tokens = pattern.findall(text)
    
    for token in tokens:
        if token.startswith('**') and token.endswith('**') and len(token) >= 4:
            run = paragraph.add_run(token[2:-2])
            run.bold = True
        elif token.startswith('*') and token.endswith('*') and len(token) >= 2 and not token.startswith('**'):
            run = paragraph.add_run(token[1:-1])
            run.italic = True
        elif token.startswith('`') and token.endswith('`') and len(token) >= 2:
            run = paragraph.add_run(token[1:-1])
            run.font.name = 'Consolas'
            run.font.size = Pt(9.5)
            run.font.color.rgb = RGBColor(30, 41, 59)
        elif token.startswith('[') and '](' in token and token.endswith(')'):
            m = re.match(r'\[(.*?)\]\((.*?)\)', token)
            if m:
                label, url = m.groups()
                run = paragraph.add_run(label)
                run.font.color.rgb = RGBColor(0, 133, 117) # Teal accent from template
                run.underline = True
            else:
                paragraph.add_run(token)
        elif token.startswith('$') and token.endswith('$') and len(token) >= 2:
            math_text = token[1:-1]
            math_text = math_text.replace(r'\pm', '±').replace(r'\le', '≤').replace(r'\ge', '≥')
            math_text = math_text.replace(r'\times', '×').replace(r'\mu', 'µ').replace(r'\tau', 'τ')
            math_text = math_text.replace(r'\omega', 'ω').replace(r'\zeta', 'ζ').replace(r'\pi', 'π')
            math_text = math_text.replace(r'\theta', 'θ').replace(r'\approx', '≈').replace(r'\circ', '°')
            math_text = math_text.replace(r'\rightarrow', '→').replace(r'\text', '').replace(r'\mathbf', '')
            math_text = re.sub(r'[{}]', '', math_text)
            run = paragraph.add_run(math_text)
            run.italic = True
        else:
            paragraph.add_run(token)

def build_word_document():
    template_path = r'C:\Users\Asem\Desktop\progress_report_final.docx'
    output_desktop_path = r'C:\Users\Asem\Desktop\FINAL_PROJECT_REPORT.docx'
    output_repo_path = r'c:\Users\Asem\Desktop\si clash\rx_sync_project\FINAL_PROJECT_REPORT.docx'
    md_path = r'c:\Users\Asem\Desktop\si clash\rx_sync_project\FINAL_PROJECT_REPORT.md'
    repo_root = r'c:\Users\Asem\Desktop\si clash\rx_sync_project'

    print(f'Loading template: {template_path}')
    doc = docx.Document(template_path)

    # 1. Update Title on Cover Page
    doc.paragraphs[2].runs[0].text = 'Final Comprehensive Technical Report'

    # 2. Clear previous body content after P11
    for p in list(doc.paragraphs[12:]):
        p._element.getparent().remove(p._element)
    for t in list(doc.tables):
        t._element.getparent().remove(t._element)

    # Add a page break after the cover page
    doc.add_page_break()

    # 3. Read and parse markdown file
    with open(md_path, 'r', encoding='utf-8') as f:
        md_text = f.read()

    lines = md_text.splitlines()
    in_code_block = False
    code_lines = []
    in_table = False
    table_lines = []
    in_quote = False
    quote_lines = []
    skip_header = True

    i = 0
    while i < len(lines):
        line = lines[i]

        # Skip top badges and top title
        if skip_header:
            if line.startswith('## 1. Executive Summary'):
                skip_header = False
            else:
                i += 1
                continue

        # Check for markdown image: ![Caption](path)
        img_match = re.match(r'^\s*!\[(.*?)\]\((.*?)\)\s*$', line)
        if img_match and not in_code_block:
            alt_text, img_rel_path = img_match.groups()
            img_full_path = os.path.normpath(os.path.join(repo_root, img_rel_path))
            if os.path.exists(img_full_path):
                img_p = doc.add_paragraph()
                img_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                img_p.paragraph_format.space_before = Pt(8)
                img_p.paragraph_format.space_after = Pt(2)
                r_img = img_p.add_run()
                # Choose width based on image
                width = Inches(5.6)
                if 'burst_fsm' in img_rel_path:
                    width = Inches(5.6)
                elif 'leds' in img_rel_path:
                    width = Inches(4.5)
                elif 'Asic' in img_rel_path:
                    width = Inches(4.2)
                r_img.add_picture(img_full_path, width=width)
                
                # Caption
                if alt_text.strip():
                    cap_p = doc.add_paragraph()
                    cap_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                    cap_p.paragraph_format.space_before = Pt(0)
                    cap_p.paragraph_format.space_after = Pt(8)
                    cap_run = cap_p.add_run(alt_text.strip())
                    cap_run.italic = True
                    cap_run.font.size = Pt(9.0)
                    cap_run.font.color.rgb = RGBColor(100, 116, 139)
            else:
                print(f"Warning: Image not found at {img_full_path}")
            i += 1
            continue

        # Code block handling
        if line.startswith('```'):
            if in_code_block:
                in_code_block = False
                code_text = '\n'.join(code_lines)
                table = doc.add_table(rows=1, cols=1)
                table.alignment = WD_TABLE_ALIGNMENT.CENTER
                cell = table.cell(0, 0)
                set_cell_background(cell, 'F1F5F9')
                set_cell_margins(cell, top=120, bottom=120, left=180, right=180)
                cp = cell.paragraphs[0]
                cp.paragraph_format.space_before = Pt(2)
                cp.paragraph_format.space_after = Pt(2)
                c_run = cp.add_run(code_text)
                c_run.font.name = 'Consolas'
                c_run.font.size = Pt(8.5)
                c_run.font.color.rgb = RGBColor(15, 23, 42)
                doc.add_paragraph()
                code_lines = []
            else:
                in_code_block = True
                code_lines = []
            i += 1
            continue

        if in_code_block:
            code_lines.append(line)
            i += 1
            continue

        # Callout / Blockquote handling
        if line.startswith('>'):
            quote_text = line.lstrip('> ').strip()
            quote_lines.append(quote_text)
            if i + 1 < len(lines) and lines[i+1].startswith('>'):
                i += 1
                continue
            else:
                full_quote = '\n'.join(quote_lines)
                table = doc.add_table(rows=1, cols=1)
                table.alignment = WD_TABLE_ALIGNMENT.CENTER
                cell = table.cell(0, 0)
                set_cell_background(cell, 'F0FDFA')
                set_cell_margins(cell, top=140, bottom=140, left=200, right=200)
                tcPr = cell._tc.get_or_add_tcPr()
                tcBorders = parse_xml(f'<w:tcBorders {nsdecls("w")}><w:left w:val="single" w:sz="36" w:space="0" w:color="008575"/><w:top w:val="none"/><w:right w:val="none"/><w:bottom w:val="none"/></w:tcBorders>')
                tcPr.append(tcBorders)
                
                qp = cell.paragraphs[0]
                qp.paragraph_format.space_before = Pt(4)
                qp.paragraph_format.space_after = Pt(4)
                add_formatted_text(qp, full_quote)
                doc.add_paragraph()
                quote_lines = []
                i += 1
                continue

        # Table handling
        if line.strip().startswith('|') and line.strip().endswith('|'):
            table_lines.append(line)
            if i + 1 < len(lines) and lines[i+1].strip().startswith('|') and lines[i+1].strip().endswith('|'):
                i += 1
                continue
            else:
                parsed_rows = []
                for tline in table_lines:
                    if re.match(r'^\s*\|(\s*:?-+:?\s*\|)+\s*$', tline):
                        continue
                    cells = [c.strip() for c in tline.strip().strip('|').split('|')]
                    parsed_rows.append(cells)
                
                if parsed_rows:
                    num_rows = len(parsed_rows)
                    num_cols = max(len(r) for r in parsed_rows)
                    tbl = doc.add_table(rows=num_rows, cols=num_cols)
                    tbl.style = 'Grid Table 4 Accent 5'
                    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
                    
                    for r_idx, row_data in enumerate(parsed_rows):
                        row = tbl.rows[r_idx]
                        is_header = (r_idx == 0)
                        for c_idx in range(num_cols):
                            cell_text = row_data[c_idx] if c_idx < len(row_data) else ""
                            cell = row.cells[c_idx]
                            set_cell_margins(cell, top=80, bottom=80, left=120, right=120)
                            p = cell.paragraphs[0]
                            p.paragraph_format.space_before = Pt(2)
                            p.paragraph_format.space_after = Pt(2)
                            if is_header:
                                add_formatted_text(p, f"**{cell_text}**")
                            else:
                                add_formatted_text(p, cell_text)
                    doc.add_paragraph()
                table_lines = []
                i += 1
                continue

        # Horizontal rule
        if line.strip() in ['---', '***', '___']:
            i += 1
            continue

        # Headings
        if line.startswith('## '):
            h_text = line[3:].strip()
            p = doc.add_heading(h_text, level=1)
            p.paragraph_format.space_before = Pt(14)
            p.paragraph_format.space_after = Pt(6)
            p.paragraph_format.keep_with_next = True
            i += 1
            continue
        elif line.startswith('### '):
            h_text = line[4:].strip()
            p = doc.add_heading(h_text, level=2)
            p.paragraph_format.space_before = Pt(10)
            p.paragraph_format.space_after = Pt(4)
            p.paragraph_format.keep_with_next = True
            i += 1
            continue
        elif line.startswith('#### '):
            h_text = line[5:].strip()
            p = doc.add_heading(h_text, level=3)
            p.paragraph_format.space_before = Pt(8)
            p.paragraph_format.space_after = Pt(3)
            p.paragraph_format.keep_with_next = True
            i += 1
            continue

        # Bullet list
        if line.strip().startswith('* ') or line.strip().startswith('- '):
            item_text = line.strip()[2:].strip()
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.left_indent = Inches(0.25)
            r_bullet = p.add_run("•  ")
            r_bullet.bold = True
            r_bullet.font.color.rgb = RGBColor(0, 133, 117)
            add_formatted_text(p, item_text)
            i += 1
            continue

        # Numbered list
        m_num = re.match(r'^\s*(\d+)\.\s+(.*)', line)
        if m_num:
            num, item_text = m_num.groups()
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.left_indent = Inches(0.25)
            r_num = p.add_run(f"{num}. ")
            r_num.bold = True
            add_formatted_text(p, item_text)
            i += 1
            continue

        # Normal text paragraph (skip div align or bare html tags)
        if line.strip() and not line.strip().startswith('<') and not line.strip().endswith('>'):
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(4)
            add_formatted_text(p, line.strip())

        i += 1

    print(f'Saving to: {output_desktop_path}')
    doc.save(output_desktop_path)
    print(f'Saving to: {output_repo_path}')
    doc.save(output_repo_path)
    print('SUCCESS! Word document updated with all SVG/PNG diagrams, WaveDrom waveforms, and hardware photos.')

if __name__ == '__main__':
    build_word_document()
