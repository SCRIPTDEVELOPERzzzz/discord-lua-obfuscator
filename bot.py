import discord
from discord.ext import commands
import subprocess
import tempfile
import os
import asyncio
from dotenv import load_dotenv

load_dotenv()

# Minimal bot setup
intents = discord.Intents.default()
intents.message_content = True

# DISABLE EVERYTHING THAT COULD CONFLICT
bot = commands.Bot(
    command_prefix='!',
    intents=intents,
    help_command=None,  # NO BUILT-IN HELP
    sync_commands=False  # NO AUTO SYNC
)

@bot.event
async def on_ready():
    print(f"✅ BOT ONLINE: {bot.user}")

def is_lua_code(content):
    """Check if content is actually Lua code"""
    # Look for Lua keywords
    lua_keywords = [
        'local ', 'function', 'if ', 'then', 'end', 'for ', 'while ',
        'repeat ', 'until', 'do ', 'return', 'break', 'print(', 'require(',
        'table.', 'string.', 'math.', ':=', '--', 'elseif', 'else'
    ]
    
    content_lower = content.lower()
    
    # Count how many Lua keywords are in the file
    keyword_count = sum(1 for keyword in lua_keywords if keyword in content_lower)
    
    # If at least 2 Lua keywords found, it's probably Lua
    return keyword_count >= 2

# ONLY 1 COMMAND - OBFUSCATE
@bot.command(name='obfuscate')
async def obfuscate(ctx):
    """Obfuscate Lua file"""
    
    # Check attachment
    if not ctx.message.attachments:
        await ctx.send("❌ Attach a file")
        return
    
    file = ctx.message.attachments[0]
    
    # Read file first
    try:
        await ctx.defer()
        content = await file.read()
        content_str = content.decode('utf-8')
    except Exception as e:
        await ctx.send(f"❌ Cannot read file: {str(e)[:100]}")
        return
    
    # Check if content is Lua (not just filename)
    if not is_lua_code(content_str):
        await ctx.send("❌ File is not Lua code\nMust contain Lua keywords like: function, local, if, print, etc.")
        return
    
    # Run obfuscator
    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            input_file = os.path.join(tmpdir, 'input.lua')
            output_file = os.path.join(tmpdir, 'output.lua')
            
            # Write input
            with open(input_file, 'w') as f:
                f.write(content_str)
            
            # Run Lua script
            result = await asyncio.create_subprocess_exec(
                'lua',
                'main_obfuscator.lua',
                input_file,
                output_file,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await asyncio.wait_for(result.communicate(), timeout=30)
            
            # Check output exists
            if not os.path.exists(output_file):
                await ctx.send("❌ Obfuscation failed")
                return
            
            # Send file
            await ctx.send(file=discord.File(output_file, filename='obfuscated.lua'))
            await ctx.send("✅ Done!")
    
    except Exception as e:
        await ctx.send(f"❌ Error: {str(e)[:100]}")

# START BOT
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
            
