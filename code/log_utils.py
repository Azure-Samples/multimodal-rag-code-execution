# Set up logging format
import logging
from colorlog import ColoredFormatter

formatter = ColoredFormatter(
    "%(log_color)s%(levelname)s%(reset)s(%(filename)s):\t%(message)s",
    log_colors={
        'DEBUG': 'blue',
        'INFO': 'green',
        'WARNING': 'yellow',
        'ERROR': 'red',
        'CRITICAL': 'red,bg_white',
    }
)

def setup_logger():
    # Create a logger
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    # Create a console handler and set the formatter
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    # Add the console handler to the logger
    logger.addHandler(console_handler)
