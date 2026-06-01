import discord
from discord.ext import commands
import tempfile
import os
import base64
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

def is_lua_code(content):
    """Check if content is actually Lua code"""
    lua_keywords = [
        'local ', 'function', 'if ', 'then', 'end', 'for ', 'while ',
        'repeat ', 'until', 'do ', 'return', 'break', 'print(', 'require(',
        'table.', 'string.', 'math.', '--', 'elseif', 'else', '==='
    ]
    
    content_lower = content.lower()
    keyword_count = sum(1 for keyword in lua_keywords if keyword in content_lower)
    
    return keyword_count >= 2

def simple_obfuscate(code):
    """Simple obfuscation without Lua"""
    import re
    
    # 1. Remove comments
    code = re.sub(r'--.*$', '', code, flags=re.MULTILINE)
    
    # 2. Remove extra whitespace
    lines = code.split('\n')
    lines = [line.strip() for line in lines if line.strip()]
    code = '\n'.join(lines)
    
    # 3. Rename common variables (simple)
    replacements = {
        'function': 'f',
        'local': 'l',
        'return': 'r',
        'if': 'i',
        'then': 't',
        'else': 'e',
        'end': 'n',
    }
    
    # Don't replace in strings/comments
    for old, new in replacements.items():
        # Only replace whole words
        code = re.sub(r'\b' + old + r'\b', new, code)
    
    # 4. Minify - remove spaces around operators
    code = re.sub(r'\s*([=+\-*/><%!]+)\s*', r'\1', code)
    code = re.sub(r'\s*([(){}[\],;:])\s*', r'\1', code)
    
    # 5. Split strings to make harder to grep
    code = code.replace('"', '".."\n.."')
    
    return code

@bot.command(name='obfuscate')
async def obfuscate(ctx):
    """Obfuscate Lua file"""
    
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
    
    # Check if Lua
    if not is_lua_code(content_str):
        await ctx.send("❌ Not Lua code\nFile must have Lua keywords")
        return
    
    try:
        # Obfuscate
        obfuscated = simple_obfuscate(content_str)
        
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
            
            await ctx.send(f"✅ Done!\nOriginal: {orig_lines} lines\nObfuscated: {obf_lines} lines")
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
