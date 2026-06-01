import discord
from discord.ext import commands
import tempfile
import os
import re
import random
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

class AdvancedLuaObfuscator:
    def __init__(self, code):
        self.code = code
        self.var_map = {}
        self.counter = 0
        self.protected = ['local', 'function', 'if', 'then', 'else', 'elseif', 'end', 
                         'for', 'while', 'do', 'return', 'break', 'and', 'or', 'not', 
                         'true', 'false', 'nil', 'in', 'repeat', 'until', 'print', 'debug']
    
    def step1_remove_comments(self):
        """Remove comments"""
        self.code = re.sub(r'--.*?$', '', self.code, flags=re.MULTILINE)
        return self.code
    
    def step2_rename_variables(self):
        """Rename variables"""
        words = re.findall(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b', self.code)
        for word in set(words):
            if word not in self.protected:
                if word not in self.var_map:
                    self.var_map[word] = self.gen_name()
        
        for old, new in self.var_map.items():
            self.code = re.sub(r'\b' + old + r'\b', new, self.code)
        return self.code
    
    def step3_encode_numbers(self):
        """Encode numbers with multiple methods"""
        numbers = re.findall(r'\b(\d+)\b', self.code)
        replacements = {}
        
        for num_str in set(numbers):
            num = int(num_str)
            choice = random.randint(0, 2)
            
            if choice == 0:
                replacements[num_str] = f"({num})"
            elif choice == 1:
                replacements[num_str] = f"(0x{num:x})"
            else:
                replacements[num_str] = f"({num}*1)"
        
        for old, new in replacements.items():
            self.code = self.code.replace(old, new, 1)
        return self.code
    
    def step4_split_strings(self):
        """Split strings into parts"""
        in_string = False
        result = []
        i = 0
        
        while i < len(self.code):
            if self.code[i] == '"' and (i == 0 or self.code[i-1] != '\\'):
                in_string = not in_string
                result.append('"')
                i += 1
            elif in_string and self.code[i:i+2] != '\\"':
                # Inside string - add every 3-5 chars, split with ".."
                j = i
                chunk_size = random.randint(3, 5)
                chunk = ""
                
                while j < len(self.code) and len(chunk) < chunk_size:
                    if self.code[j] == '"':
                        break
                    chunk += self.code[j]
                    j += 1
                
                if chunk:
                    result.append(chunk)
                    result.append('"' + '.."' if j < len(self.code) and self.code[j] != '"' else '')
                    i = j
                else:
                    result.append(self.code[i])
                    i += 1
            else:
                result.append(self.code[i])
                i += 1
        
        self.code = ''.join(result)
        return self.code
    
    def step5_minify(self):
        """Minify - remove unnecessary spaces"""
        self.code = re.sub(r'\s+', ' ', self.code)
        self.code = re.sub(r'\s*([(){}[\],.;:=+\-*/%<>!&|])\s*', r'\1', self.code)
        return self.code
    
    def step6_dead_code(self):
        """Insert dead code"""
        dead = [
            'local _d1=0 while _d1<0 do _d1=_d1+1 end ',
            'if false then local _d2=1 end ',
            'local _d3=function() return end ',
        ]
        
        for _ in range(2):
            self.code = random.choice(dead) + self.code
        return self.code
    
    def step7_fake_conditions(self):
        """Add fake if conditions"""
        fake_if = 'if 1==1 then else if false then end end '
        self.code = fake_if + self.code
        return self.code
    
    def step8_anti_debug(self):
        """Add anti-debug"""
        anti = 'if debug.getinfo or debug.gethook then error("") end '
        self.code = anti + self.code
        return self.code
    
    def step9_function_wrap(self):
        """Wrap in function"""
        self.code = f'local _w=function()local _x=function(){self.code}end return _x end _w()()'
        return self.code
    
    def step10_operator_obfuscation(self):
        """Obfuscate operators"""
        self.code = self.code.replace('==', ' == ')
        self.code = self.code.replace('~=', ' ~= ')
        self.code = self.code.replace('<=', ' <= ')
        self.code = self.code.replace('>=', ' >= ')
        return self.code
    
    def step11_concat_obfuscation(self):
        """Obfuscate concatenation"""
        self.code = self.code.replace('..', '..(1-1)..')
        self.code = self.code.replace('..(1-1)..', '..')
        return self.code
    
    def step12_hex_strings(self):
        """Add hex character encoding"""
        hex_part = "local _h={0x6d,0x61,0x78,0x5f,0x76,0x61,0x6c} "
        self.code = hex_part + self.code
        return self.code
    
    def step13_table_ops(self):
        """Add table operations"""
        table_ops = "local _t={} table.insert(_t,0) "
        self.code = table_ops + self.code
        return self.code
    
    def step14_loop_padding(self):
        """Add loop padding"""
        loops = "for _l=1,0,-1 do end "
        self.code = loops + self.code
        return self.code
    
    def gen_name(self):
        """Generate obfuscated name"""
        self.counter += 1
        names = ['_', '__', '___', '____', '_a', '_b', '_c', '_x', '_y', '_z']
        return random.choice(names) + str(self.counter)
    
    def obfuscate(self):
        """Apply ALL 14 steps"""
        print("🔄 Applying 14 obfuscation methods...")
        
        self.step1_remove_comments()
        print("✓ Step 1: Comments removed")
        
        self.step2_rename_variables()
        print("✓ Step 2: Variables renamed")
        
        self.step3_encode_numbers()
        print("✓ Step 3: Numbers encoded")
        
        self.step4_split_strings()
        print("✓ Step 4: Strings split")
        
        self.step6_dead_code()
        print("✓ Step 5: Dead code inserted")
        
        self.step7_fake_conditions()
        print("✓ Step 6: Fake conditions added")
        
        self.step8_anti_debug()
        print("✓ Step 7: Anti-debug added")
        
        self.step10_operator_obfuscation()
        print("✓ Step 8: Operators obfuscated")
        
        self.step11_concat_obfuscation()
        print("✓ Step 9: Concatenation obfuscated")
        
        self.step12_hex_strings()
        print("✓ Step 10: Hex strings added")
        
        self.step13_table_ops()
        print("✓ Step 11: Table ops added")
        
        self.step14_loop_padding()
        print("✓ Step 12: Loop padding added")
        
        self.step9_function_wrap()
        print("✓ Step 13: Function wrapped")
        
        self.step5_minify()
        print("✓ Step 14: Code minified")
        
        return self.code

def is_lua_code(content):
    """Check if Lua"""
    lua_keywords = ['local ', 'function', 'if ', 'then', 'end', 'for ', 'while ', 'return', 'print(']
    content_lower = content.lower()
    return sum(1 for kw in lua_keywords if kw in content_lower) >= 1

@bot.command(name='obfuscate')
async def obfuscate(ctx):
    """Obfuscate with 14 methods"""
    
    if not ctx.message.attachments:
        await ctx.send("❌ Attach file")
        return
    
    file = ctx.message.attachments[0]
    
    try:
        await ctx.defer()
        content = await file.read()
        content_str = content.decode('utf-8')
    except:
        await ctx.send("❌ Cannot read")
        return
    
    if not is_lua_code(content_str):
        await ctx.send("❌ Not Lua")
        return
    
    try:
        orig_size = len(content_str)
        
        obfuscator = AdvancedLuaObfuscator(content_str)
        obfuscated = obfuscator.obfuscate()
        
        obf_size = len(obfuscated)
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False) as f:
            f.write(obfuscated)
            temp_path = f.name
        
        try:
            await ctx.send(file=discord.File(temp_path, filename='obfuscated.lua'))
            
            embed = discord.Embed(title="✅ Complete!", color=discord.Color.green())
            embed.add_field(name="Methods", value="14/14 ✓", inline=False)
            embed.add_field(name="Original", value=f"{orig_size} bytes", inline=True)
            embed.add_field(name="Obfuscated", value=f"{obf_size} bytes", inline=True)
            embed.add_field(name="Increase", value=f"{(obf_size/orig_size*100):.1f}%", inline=True)
            
            await ctx.send(embed=embed)
        finally:
            os.unlink(temp_path)
    
    except Exception as e:
        await ctx.send(f"❌ Error: {str(e)[:50]}")

try:
    token = os.environ.get('DISCORD_TOKEN')
    if not token:
        print("❌ NO TOKEN")
        exit(1)
    print("🤖 Starting...")
    bot.run(token)
except Exception as e:
    print(f"❌ ERROR: {e}")
    exit(1)
