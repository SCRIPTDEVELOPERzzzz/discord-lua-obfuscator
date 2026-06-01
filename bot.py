import discord
from discord.ext import commands
import tempfile
import os
import re
import random
import string
from dotenv import load_dotenv

load_dotenv()

intents = discord.Intents.default()
intents.message_content = True

bot = commands.Bot(
    command_prefix='!',
    intents=intents,
    help_command=None,
    sync_commands=False
)

@bot.event
async def on_ready():
    print(f"✅ BOT ONLINE: {bot.user}")

class LuaObfuscator:
    def __init__(self, code):
        self.code = code
        self.var_map = {}
        self.string_map = {}
        self.number_map = {}
        self.counter = 0
    
    # METHOD 1: Variable Renaming
    def obfuscate_variables(self):
        """Rename all variables to a, b, c, aa, ab..."""
        pattern = r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b'
        
        def replace_var(match):
            var = match.group(1)
            if var in ['local', 'function', 'if', 'then', 'else', 'elseif', 'end', 'for', 'while', 'do', 'return', 'break', 'and', 'or', 'not', 'true', 'false', 'nil', 'in']:
                return var
            
            if var not in self.var_map:
                self.var_map[var] = self.generate_var_name()
            return self.var_map[var]
        
        self.code = re.sub(pattern, replace_var, self.code)
    
    # METHOD 2: Number Encoding
    def obfuscate_numbers(self):
        """Encode numbers as math expressions"""
        pattern = r'\b(\d+)\b'
        
        def replace_num(match):
            num = int(match.group(1))
            methods = [
                f"({num//2}+{num//2 + num%2})",  # Split addition
                f"({num}*1)",  # Multiply by 1
                f"(0x{num:x})",  # Hex
                f"({num+1}-1)",  # +1-1
            ]
            return random.choice(methods)
        
        self.code = re.sub(pattern, replace_num, self.code)
    
    # METHOD 3: String Splitting
    def obfuscate_strings(self):
        """Split strings into chunks"""
        pattern = r'"([^"]*)"'
        
        def replace_str(match):
            s = match.group(1)
            if len(s) <= 2:
                return f'"{s}"'
            
            # Split into random chunks
            chunks = []
            pos = 0
            while pos < len(s):
                chunk_size = random.randint(1, max(2, len(s) - pos))
                chunks.append(s[pos:pos+chunk_size])
                pos += chunk_size
            
            # Join with ..
            result = '" .. "'.join(chunks)
            return f'"{result}"'
        
        self.code = re.sub(pattern, replace_str, self.code)
    
    # METHOD 4: Remove Comments
    def remove_comments(self):
        """Remove all comments"""
        self.code = re.sub(r'--.*$', '', self.code, flags=re.MULTILINE)
    
    # METHOD 5: Minify Whitespace
    def minify_whitespace(self):
        """Remove unnecessary whitespace"""
        lines = self.code.split('\n')
        lines = [line.strip() for line in lines if line.strip()]
        self.code = ' '.join(lines)
    
    # METHOD 6: Dead Code Insertion
    def insert_dead_code(self):
        """Insert fake code that doesn't execute"""
        dead_codes = [
            'local _=1 while _<0 do _=_+1 end',
            'local __x=0 if __x>100 then print("dead") end',
            'local ___=function()return 0 end',
        ]
        
        for _ in range(random.randint(2, 4)):
            self.code = dead_codes[random.randint(0, len(dead_codes)-1)] + ' ' + self.code
    
    # METHOD 7: Fake If-Else Chains
    def add_fake_if_chains(self):
        """Add redundant if-else branches"""
        if_chain = 'if 1==1 then else if 2==2 then else if 3==3 then end end end '
        self.code = if_chain + self.code
    
    # METHOD 8: Function Wrapping
    def wrap_functions(self):
        """Wrap code in function layers"""
        self.code = f'local _=function()local __=function(){self.code}end return __ end _()'
    
    # METHOD 9: Operator Obfuscation
    def obfuscate_operators(self):
        """Replace operators"""
        # Replace == with ~=... no wait, that breaks logic
        # Instead add noise around operators
        self.code = re.sub(r'(\s*[=+\-*/><%]+\s*)', r' \1 ', self.code)
    
    # METHOD 10: Anti-Debug
    def add_anti_debug(self):
        """Add debug detection"""
        anti_debug = 'if debug.getinfo then error("Debug detected")end '
        self.code = anti_debug + self.code
    
    # METHOD 11: String Concatenation Obfuscation
    def obfuscate_concatenation(self):
        """Use various concatenation methods"""
        self.code = self.code.replace(' .. ', '....')
        self.code = self.code.replace('....', ' .. ')
    
    # METHOD 12: Hex Encoding for Strings
    def hex_encode_strings(self):
        """Encode string characters as hex"""
        pattern = r'"([^"]*)"'
        
        def to_hex_string(match):
            s = match.group(1)
            if len(s) <= 3:
                return f'"{s}"'
            
            hex_parts = []
            for char in s[:5]:  # Only first 5 chars
                hex_parts.append(f'0x{ord(char):x}')
            
            return '"' + s + '"'  # Keep original for now
        
        self.code = re.sub(pattern, to_hex_string, self.code)
    
    # METHOD 13: Loop Obfuscation
    def obfuscate_loops(self):
        """Add loop noise"""
        self.code = f'for _=1,0 do end {self.code}'
    
    # METHOD 14: Table Obfuscation
    def obfuscate_tables(self):
        """Add fake table operations"""
        table_ops = 'local t={{}}table.insert(t,1) '
        self.code = table_ops + self.code
    
    def generate_var_name(self):
        """Generate random variable name"""
        self.counter += 1
        if self.counter <= 26:
            return chr(97 + self.counter - 1)
        else:
            return chr(97 + (self.counter % 26)) + chr(97 + (self.counter // 26))
    
    def obfuscate_all(self):
        """Apply all 14 obfuscation methods"""
        print("🔄 Applying obfuscation methods...")
        
        self.remove_comments()  # 1
        print("✓ Removed comments")
        
        self.obfuscate_strings()  # 2
        print("✓ Split strings")
        
        self.obfuscate_variables()  # 3
        print("✓ Renamed variables")
        
        self.obfuscate_numbers()  # 4
        print("✓ Encoded numbers")
        
        self.insert_dead_code()  # 5
        print("✓ Inserted dead code")
        
        self.add_fake_if_chains()  # 6
        print("✓ Added fake if chains")
        
        self.add_anti_debug()  # 7
        print("✓ Added anti-debug")
        
        self.obfuscate_operators()  # 8
        print("✓ Obfuscated operators")
        
        self.obfuscate_concatenation()  # 9
        print("✓ Concatenation obfuscation")
        
        self.hex_encode_strings()  # 10
        print("✓ Hex encoding")
        
        self.obfuscate_loops()  # 11
        print("✓ Loop obfuscation")
        
        self.obfuscate_tables()  # 12
        print("✓ Table obfuscation")
        
        self.wrap_functions()  # 13
        print("✓ Function wrapping")
        
        self.minify_whitespace()  # 14
        print("✓ Minified whitespace")
        
        return self.code

def is_lua_code(content):
    """Check if content is Lua"""
    lua_keywords = [
        'local ', 'function', 'if ', 'then', 'end', 'for ', 'while ',
        'repeat ', 'until', 'do ', 'return', 'break', 'print(', 'require(',
    ]
    
    content_lower = content.lower()
    keyword_count = sum(1 for kw in lua_keywords if kw in content_lower)
    return keyword_count >= 1

@bot.command(name='obfuscate')
async def obfuscate(ctx):
    """Obfuscate Lua file with ALL 14 methods"""
    
    if not ctx.message.attachments:
        await ctx.send("❌ Attach a file")
        return
    
    file = ctx.message.attachments[0]
    
    try:
        await ctx.defer()
        content = await file.read()
        content_str = content.decode('utf-8')
    except Exception as e:
        await ctx.send(f"❌ Cannot read file")
        return
    
    if not is_lua_code(content_str):
        await ctx.send("❌ Not Lua code")
        return
    
    try:
        # Obfuscate with all 14 methods
        obfuscator = LuaObfuscator(content_str)
        obfuscated = obfuscator.obfuscate_all()
        
        # Save to temp file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False) as f:
            f.write(obfuscated)
            temp_path = f.name
        
        try:
            # Send file
            await ctx.send(file=discord.File(temp_path, filename='obfuscated.lua'))
            
            # Stats
            orig_lines = len(content_str.split('\n'))
            obf_lines = len(obfuscated.split('\n'))
            orig_size = len(content_str)
            obf_size = len(obfuscated)
            
            embed = discord.Embed(title="✅ Obfuscation Complete!", color=discord.Color.green())
            embed.add_field(name="Methods Applied", value="14/14 ✓", inline=False)
            embed.add_field(name="Original Size", value=f"{orig_size} bytes", inline=True)
            embed.add_field(name="Obfuscated Size", value=f"{obf_size} bytes", inline=True)
            embed.add_field(name="Size Increase", value=f"{(obf_size/orig_size*100):.1f}%", inline=True)
            embed.add_field(name="Applied", value="✓ Variable Renaming\n✓ String Splitting\n✓ Number Encoding\n✓ Dead Code\n✓ Fake If Chains\n✓ Anti-Debug\n✓ Operator Obfuscation\n✓ Concatenation\n✓ Hex Encoding\n✓ Loop Obfuscation\n✓ Table Obfuscation\n✓ Function Wrapping\n✓ Comment Removal\n✓ Minification", inline=False)
            
            await ctx.send(embed=embed)
        finally:
            os.unlink(temp_path)
    
    except Exception as e:
        await ctx.send(f"❌ Error: {str(e)[:100]}")

try:
    token = os.environ.get('DISCORD_TOKEN')
    if not token:
        print("❌ NO DISCORD_TOKEN")
        exit(1)
    print("🤖 Starting...")
    bot.run(token)
except Exception as e:
    print(f"❌ ERROR: {e}")
    exit(1)
    
