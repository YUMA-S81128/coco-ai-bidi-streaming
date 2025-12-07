import asyncio
import logging
import os
import traceback
from fastapi import WebSocket, WebSocketDisconnect
from google import genai
from google.genai import types
from agent.app.tools.image_gen import generate_image

logger = logging.getLogger(__name__)

class ADKAgent:
    def __init__(self, user_id: str | None = None, chat_id: str | None = None):
        # Initialize Vertex AI Client
        # Ensure GOOGLE_APPLICATION_CREDENTIALS is set or environment is configured
        # and PROJECT_ID is available (or inferred)
        project_id = os.environ.get("GOOGLE_CLOUD_PROJECT")
        location = "asia-northeast1" # Tokyo region
        
        self.client = genai.Client(
            vertexai=True,
            project=project_id,
            location=location,
            http_options={"api_version": "v1alpha"}
        )
        self.model_id = "gemini-2.0-flash-exp"
        self.user_id = user_id
        self.chat_id = chat_id
        
        self.session_ended = False

        # Define tool with context binding
        async def generate_image_tool(prompt: str):
            return await generate_image(prompt, self.user_id, self.chat_id)
            
        async def end_session_tool():
            """Ends the current session when the user says goodbye or asks to stop."""
            self.session_ended = True
            return "SESSION_ENDED"

        self.tools = [generate_image_tool, end_session_tool]
        
        # System instruction for autonomous image generation and session management
        system_instruction = (
            "You are a helpful AI assistant. "
            "You can generate images to support your explanation or when you think it would be fun or helpful. "
            "You do NOT need to wait for the user to explicitly ask for an image. "
            "If you are describing something visual, or if the context suggests an image would be good, "
            "proactively use the 'generate_image_tool' to create one. "
            "When you generate an image, let the user know you are doing so. "
            "If the user says 'goodbye', 'stop', 'end session', or similar, call the 'end_session_tool' to close the connection."
        )

        # Configuration for the session
        self.config = {
            "response_modalities": ["AUDIO"],
            "tools": self.tools,
            "system_instruction": system_instruction,
        }

    async def handle_session(self, websocket: WebSocket):
        """
        Handles the bidirectional streaming session between WebSocket and Gemini.
        """
        try:
            async with self.client.aio.live.connect(model=self.model_id, config=self.config) as session:
                logger.info("Connected to Gemini Live API")
                
                async def receive_from_client():
                    try:
                        while True:
                            # Receive audio data from client (assuming raw bytes or specific format)
                            # For simplicity, assuming client sends bytes.
                            # If client sends JSON (e.g. for control events), need to handle that.
                            message = await websocket.receive()
                            
                            if "bytes" in message:
                                data = message["bytes"]
                                # Send audio chunk to Gemini
                                # mime_type should be consistent with what client sends (e.g. pcm)
                                await session.send(input={"data": data, "mime_type": "audio/pcm"}, end_of_turn=False)
                            elif "text" in message:
                                # Handle text messages if any (e.g. initial config)
                                pass
                                
                    except WebSocketDisconnect:
                        logger.info("Client disconnected")
                    except Exception as e:
                        logger.error(f"Error receiving from client: {e}")
                        traceback.print_exc()

                async def send_to_client():
                    try:
                        async for response in session.receive():
                            # Handle audio response
                            if response.data:
                                await websocket.send_bytes(response.data)
                            
                            # Check if session ended flag is set
                            if self.session_ended:
                                logger.info("Session ended by tool")
                                await websocket.send_json({"type": "end_session"})
                                break
                            
                    except Exception as e:
                        logger.error(f"Error receiving from Gemini: {e}")
                        traceback.print_exc()

                # Run both tasks concurrently
                await asyncio.gather(receive_from_client(), send_to_client())

        except Exception as e:
            logger.error(f"Error in Gemini session: {e}")
            traceback.print_exc()
            try:
                await websocket.close()
            except:
                pass
