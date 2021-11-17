#include <GlkView/glk.h>

/* multiwin.c: Sample program for Glk API, version 0.5.
    Designed by Andrew Plotkin <erkyrath@eblong.com>
    http://www.eblong.com/zarf/glk/index.html
    This program is in the public domain.
*/

/* This example demonstrates multiple windows and timed input in the
    Glk API. */

/* This is the cleanest possible form of a Glk program. It includes only
    "glk.h", and doesn't call any functions outside Glk at all. We even
    define our own string functions, rather than relying on the
    standard libraries. */

/* We also define our own TRUE and FALSE and NULL. */
#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif
#ifndef NULL
#define NULL 0
#endif

/* The story and status windows. */
static winid_t mainwin1 = NULL;
static winid_t mainwin2 = NULL;
static winid_t statuswin = NULL;

/* Key windows don't get stored in a global variable; we'll find them
    by iterating over the list and looking for this rock value. */
#define KEYWINROCK (97)

/* For the two main windows, we keep a flag saying whether that window
    has a line input request pending. (Because if it does, we need to
    cancel the line input before printing to that window.) */
static int inputpending1, inputpending2;
/* When we cancel line input, we should remember how many characters
    had been typed. This lets us restart the input with those characters
    already in place. */
static int already1, already2;

/* There's a three-second timer which can be on or off. */
static int timer_on = FALSE;

/* Forward declarations */
void glk_main(void);

static void draw_statuswin(void);
static void draw_keywins(void);
static void perform_key(winid_t win, glui32 key);
static void perform_timer(void);

static int str_eq(char *s1, char *s2);
static int str_len(char *s1);
static char *str_cpy(char *s1, char *s2);
static char *str_cat(char *s1, char *s2);
static void num_to_str(char *buf, int num);

static void verb_help(winid_t win);
static void verb_jump(winid_t win);
static void verb_yada(winid_t win);
static void verb_both(winid_t win);
static void verb_clear(winid_t win);
static void verb_page(winid_t win);
static void verb_pageboth(winid_t win);
static void verb_timer(winid_t win);
static void verb_untimer(winid_t win);
static void verb_chars(winid_t win);
static void verb_quit(winid_t win);

/* The glk_main() function is called by the Glk system; it's the main entry
    point for your program. */
void glk_main(void)
{
    char commandbuf1[256]; /* For mainwin1 */
    char commandbuf2[256]; /* For mainwin2 */

    /* Open the main windows. */
    mainwin1 = glk_window_open(0, 0, 0, wintype_TextBuffer, 1);
    if (!mainwin1) {
        /* It's possible that the main window failed to open. There's
            nothing we can do without it, so exit. */
        return; 
    }
    
    /* Open a second window: a text grid, above the main window, five 
        lines high. It is possible that this will fail also, but we accept 
        that. */
    statuswin = glk_window_open(mainwin1, 
        winmethod_Above | winmethod_Fixed, 
        5, wintype_TextGrid, 0);
        
    /* And a third window, a second story window below the main one. */
    mainwin2 = glk_window_open(mainwin1, 
        winmethod_Below | winmethod_Proportional, 
        50, wintype_TextBuffer, 0);
        
    /* We're going to be switching from one window to another all the
        time. So we'll be setting the output stream on a case-by-case
        basis. Every function that prints must set the output stream
        first. (Contrast model.c, where the output stream is always the
        main window, and every function that changes that must set it
        back afterwards.) */
    
    glk_set_window(mainwin1);
    glk_put_string("Multiwin\nAn Interactive Sample Glk Program\n");
    glk_put_string("By Andrew Plotkin.\nRelease 3.\n");
    glk_put_string("Type \"help\" for a list of commands.\n");
    
    glk_set_window(mainwin2);
    glk_put_string("Note that the upper left-hand window accepts character");
    glk_put_string(" input. Hit 'h' to split the window horizontally, 'v' to");
    glk_put_string(" split the window vertically, 'c' to close a window,");
    glk_put_string(" and any other key (including special keys) to display");
    glk_put_string(" key codes. All new windows accept these same keys as");
    glk_put_string(" well.\n\n");
    glk_put_string("This bottom window accepts normal line input.\n");
    
    if (statuswin) {
        /* For fun, let's open a fourth window now, splitting the status
            window. */
        winid_t keywin;
        keywin = glk_window_open(statuswin, 
            winmethod_Left | winmethod_Proportional, 
            66, wintype_TextGrid, KEYWINROCK);
        if (keywin) {
            glk_request_char_event(keywin);
        }
    }
    
    /* Draw the key window now, since we don't draw it every input (as
        we do the status window. */
    draw_keywins();

    inputpending1 = FALSE;
    inputpending2 = FALSE;
    already1 = 0;
    already2 = 0;
    
    while (1) {
        char *cx, *cmd=NULL;
        int doneloop, len;
        winid_t whichwin=0;
        event_t ev;
        
        draw_statuswin();
        /* We're not redrawing the key windows every command. */
        
        /* Either main window, or both, could already have line input
            pending. If so, leave that window alone. If there is no
            input pending on a window, set a line input request, but
            keep around any characters that were in the buffer already. */
        
        if (mainwin1 && !inputpending1) {
            glk_set_window(mainwin1);
            glk_put_string("\n>");
            /* We request up to 255 characters. The buffer can hold 256, 
                but we are going to stick a null character at the end, so 
                we have to leave room for that. Note that the Glk library 
                does *not* put on that null character. */
            glk_request_line_event(mainwin1, commandbuf1, 255, already1);
            inputpending1 = TRUE;
        }
        
        if (mainwin2 && !inputpending2) {
            glk_set_window(mainwin2);
            glk_put_string("\n>");
            /* See above. */
            glk_request_line_event(mainwin2, commandbuf2, 255, already2);
            inputpending2 = TRUE;
        }
        
        doneloop = FALSE;
        while (!doneloop) {
        
            /* Grab an event. */
            glk_select(&ev);
            
            switch (ev.type) {
            
                case evtype_LineInput:
                    /* If the event comes from one main window or the other,
                        we mark that window as no longer having line input
                        pending. We also set commandbuf to point to the
                        appropriate buffer. Then we leave the event loop. */
                    if (mainwin1 && ev.win == mainwin1) {
                        whichwin = mainwin1;
                        inputpending1 = FALSE;
                        cmd = commandbuf1;
                        doneloop = TRUE;
                    }
                    else if (mainwin2 && ev.win == mainwin2) {
                        whichwin = mainwin2;
                        inputpending2 = FALSE;
                        cmd = commandbuf2;
                        doneloop = TRUE;
                    }
                    break;
                    
                case evtype_CharInput:
                    /* It's a key event, from one of the keywins. We
                        call a subroutine rather than exiting the
                        event loop (although I could have done it
                        that way too.) */
                    perform_key(ev.win, ev.val1);
                    break;
                
                case evtype_Timer:
                    /* It's a timer event. This does exit from the event
                        loop, since we're going to interrupt input in
                        mainwin1 and then re-print the prompt. */
                    whichwin = NULL;
                    cmd = NULL; 
                    doneloop = TRUE;
                    break;
                    
                case evtype_Arrange:
                    /* Windows have changed size, so we have to redraw the
                        status window and key window. But we stay in the
                        event loop. */
                    draw_statuswin();
                    draw_keywins();
                    break;
            }
        }
        
        if (cmd == NULL) {
            /* It was a timer event. */
            perform_timer();
            continue;
        }
        
        /* It was a line input event. cmd now points at a line of input
            from one of the main windows. */
        
        /* The line we have received in commandbuf is not null-terminated.
            We handle that first. */
        len = ev.val1; /* Will be between 0 and 255, inclusive. */
        cmd[len] = '\0';
        
        /* Then squash to lower-case. */
        for (cx = cmd; *cx; cx++) { 
            *cx = glk_char_to_lower(*cx);
        }
        
        /* Then trim whitespace before and after. */
        
        for (cx = cmd; *cx == ' '; cx++, len--) { };
        
        cmd = cx;
        
        for (cx = cmd+len-1; cx >= cmd && *cx == ' '; cx--) { };
        *(cx+1) = '\0';
        
        /* cmd now points to a nice null-terminated string. We'll do the
            simplest possible parsing. */
        if (str_eq(cmd, "")) {
            glk_set_window(whichwin);
            glk_put_string("Excuse me?\n");
        }
        else if (str_eq(cmd, "help")) {
            verb_help(whichwin);
        }
        else if (str_eq(cmd, "yada")) {
            verb_yada(whichwin);
        }
        else if (str_eq(cmd, "both")) {
            verb_both(whichwin);
        }
        else if (str_eq(cmd, "clear")) {
            verb_clear(whichwin);
        }
        else if (str_eq(cmd, "page")) {
            verb_page(whichwin);
        }
        else if (str_eq(cmd, "pageboth")) {
            verb_pageboth(whichwin);
        }
        else if (str_eq(cmd, "timer")) {
            verb_timer(whichwin);
        }
        else if (str_eq(cmd, "untimer")) {
            verb_untimer(whichwin);
        }
        else if (str_eq(cmd, "chars")) {
            verb_chars(whichwin);
        }
        else if (str_eq(cmd, "jump")) {
            verb_jump(whichwin);
        }
        else if (str_eq(cmd, "quit")) {
            verb_quit(whichwin);
        }
        else {
            glk_set_window(whichwin);
            glk_put_string("I don't understand the command \"");
            glk_put_string(cmd);
            glk_put_string("\".\n");
        }
        
        if (whichwin == mainwin1)
            already1 = 0;
        else if (whichwin == mainwin2)
            already2 = 0;
    }
}

static void draw_statuswin(void)
{
    glui32 width, height;
    
    if (!statuswin) {
        /* It is possible that the window was not successfully 
            created. If that's the case, don't try to draw it. */
        return;
    }
    
    glk_set_window(statuswin);
    glk_window_clear(statuswin);
    
    glk_window_get_size(statuswin, &width, &height);
    
    /* Draw a decorative compass rose in the center. */
    width = (width/2);
    if (width > 0)
        width--;
    height = (height/2);
    if (height > 0)
        height--;
        
    glk_window_move_cursor(statuswin, width, height+0);
    glk_put_string("\\|/");
    glk_window_move_cursor(statuswin, width, height+1);
    glk_put_string("-*-");
    glk_window_move_cursor(statuswin, width, height+2);
    glk_put_string("/|\\");
    
}

/* This draws some corner decorations in *every* key window -- the
    one created at startup, and any later ones. It finds them all
    with glk_window_iterate. */
static void draw_keywins(void)
{
    winid_t win;
    glui32 rock;
    glui32 width, height;
    
    for (win = glk_window_iterate(NULL, &rock);
            win;
            win = glk_window_iterate(win, &rock)) {
        if (rock == KEYWINROCK) {
            glk_set_window(win);
            glk_window_clear(win);
            glk_window_get_size(win, &width, &height);
            glk_window_move_cursor(win, 0, 0);
            glk_put_char('O');
            glk_window_move_cursor(win, width-1, 0);
            glk_put_char('O');
            glk_window_move_cursor(win, 0, height-1);
            glk_put_char('O');
            glk_window_move_cursor(win, width-1, height-1);
            glk_put_char('O');
        }
    }
}

/* React to character input in a key window. */
static void perform_key(winid_t win, glui32 key)
{
    glui32 width, height, len;
    int ix;
    char buf[128], keyname[64];
    
    if (key == 'h' || key == 'v') {
        winid_t newwin;
        glui32 loc;
        /* Open a new keywindow. */
        if (key == 'h')
            loc = winmethod_Right | winmethod_Proportional;
        else
            loc = winmethod_Below | winmethod_Proportional;
        newwin = glk_window_open(win, 
            loc, 50, wintype_TextGrid, KEYWINROCK);
        /* Since the new window has rock value KEYWINROCK, the
            draw_keywins() routine will redraw it. */
        if (newwin) {
            /* Request character input. In this program, only keywins
                get char input, so the CharInput events always call
                perform_key() -- and so the new window will respond
                to keys just as this one does. */
            glk_request_char_event(newwin);
            /* We now have to redraw the keywins, because any or all of
                them could have changed size when we opened newwin.
                glk_window_open() does not generate Arrange events; we
                have to do the redrawing manually. */
            draw_keywins();
        }
        /* Re-request character input for this window, so that future
            keys are accepted. */
        glk_request_char_event(win);
        return;
    }
    else if (key == 'c') {
        /* Close this keywindow. */
        glk_window_close(win, NULL);
        /* Again, any key windows could have changed size. Also the
            status window could have (if this was the last key window). */
        draw_keywins();
        draw_statuswin();
        return;
    }
    
    /* Print a string naming the key that was just hit. */
    
    switch (key) {
        case ' ':
            str_cpy(keyname, "space");
            break;
        case keycode_Left:
            str_cpy(keyname, "left");
            break;
        case keycode_Right:
            str_cpy(keyname, "right");
            break;
        case keycode_Up:
            str_cpy(keyname, "up");
            break;
        case keycode_Down:
            str_cpy(keyname, "down");
            break;
        case keycode_Return:
            str_cpy(keyname, "return");
            break;
        case keycode_Delete:
            str_cpy(keyname, "delete");
            break;
        case keycode_Escape:
            str_cpy(keyname, "escape");
            break;
        case keycode_Tab:
            str_cpy(keyname, "tab");
            break;
        case keycode_PageUp:
            str_cpy(keyname, "page up");
            break;
        case keycode_PageDown:
            str_cpy(keyname, "page down");
            break;
        case keycode_Home:
            str_cpy(keyname, "home");
            break;
        case keycode_End:
            str_cpy(keyname, "end");
            break;
        default:
            if (key >= keycode_Func1 && key < keycode_Func12) {
                str_cpy(keyname, "function key");
            }
            else if (key < 32) {
                str_cpy(keyname, "ctrl-");
                keyname[5] = '@' + key;
                keyname[6] = '\0';
            }
            else if (key <= 255) {
                keyname[0] = key;
                keyname[1] = '\0';
            }
            else {
                str_cpy(keyname, "unknown key");
            }
            break;
    }
    
    str_cpy(buf, "Key: ");
    str_cat(buf, keyname);
    
    len = str_len(buf);
    
    /* Print the string centered in this window. */
    glk_set_window(win);
    glk_window_get_size(win, &width, &height);
    glk_window_move_cursor(win, 0, height/2);
    for (ix=0; ix<width; ix++)
        glk_put_char(' ');
        
    width = width/2;
    len = len/2;
    
    if (width > len)
        width = width-len;
    else
        width = 0;
    
    glk_window_move_cursor(win, width, height/2);
    glk_put_string(buf);
    
    /* Re-request character input for this window, so that future
        keys are accepted. */
    glk_request_char_event(win);
}

/* React to a timer event. This just prints "Tick" in mainwin1, but it
    first has to cancel line input if any is pending. */
static void perform_timer()
{
    event_t ev;
    
    if (!mainwin1)
        return;
    
    if (inputpending1) {
        glk_cancel_line_event(mainwin1, &ev);
        if (ev.type == evtype_LineInput)
            already1 = ev.val1;
        inputpending1 = FALSE;
    }

    glk_set_window(mainwin1);
    glk_put_string("Tick.\n");
}

/* This is a utility function. Given a main window, it finds the
    "other" main window (if both actually exist) and cancels line
    input in that other window (if input is pending.) It does not
    set the output stream to point there, however. If there is only
    one main window, this returns 0. */
static winid_t print_to_otherwin(winid_t win)
{
    winid_t otherwin = NULL;
    event_t ev;

    if (win == mainwin1) {
        if (mainwin2) {
            otherwin = mainwin2;
            glk_cancel_line_event(mainwin2, &ev);
            if (ev.type == evtype_LineInput)
                already2 = ev.val1;
            inputpending2 = FALSE;
        }
    }
    else if (win == mainwin2) {
        if (mainwin1) {
            otherwin = mainwin1;
            glk_cancel_line_event(mainwin1, &ev);
            if (ev.type == evtype_LineInput)
                already1 = ev.val1;
            inputpending1 = FALSE;
        }
    }
    
    return otherwin;
}

static void verb_help(winid_t win)
{
    glk_set_window(win);
    
    glk_put_string("This model only understands the following commands:\n");
    glk_put_string("HELP: Display this list.\n");
    glk_put_string("JUMP: Print a short message.\n");
    glk_put_string("YADA: Print a long paragraph.\n");
    glk_put_string("BOTH: Print a short message in both main windows.\n");
    glk_put_string("CLEAR: Clear one window.\n");
    glk_put_string("PAGE: Print thirty lines, demonstrating paging.\n");
    glk_put_string("PAGEBOTH: Print thirty lines in each window.\n");
    glk_put_string("TIMER: Turn on a timer, which ticks in the upper ");
    glk_put_string("main window every three seconds.\n");
    glk_put_string("UNTIMER: Turns off the timer.\n");
    glk_put_string("CHARS: Prints the entire Latin-1 character set.\n");
    glk_put_string("QUIT: Quit and exit.\n");
}

static void verb_jump(winid_t win)
{
    glk_set_window(win);
    
    glk_put_string("You jump on the fruit, spotlessly.\n");
}

/* Print some text in both windows. This uses print_to_otherwin() to
    find the other window and prepare it for printing. */
static void verb_both(winid_t win)
{
    winid_t otherwin;
    
    glk_set_window(win);
    glk_put_string("Something happens in this window.\n");
    
    otherwin = print_to_otherwin(win);
    
    if (otherwin) {
        glk_set_window(otherwin);
        glk_put_string("Something happens in the other window.\n");
    }
}

/* Clear a window. */
static void verb_clear(winid_t win)
{
    glk_window_clear(win);
}

/* Print thirty lines. */
static void verb_page(winid_t win)
{
    int ix;
    char buf[32];
    
    glk_set_window(win);
    for (ix=0; ix<30; ix++) {
        num_to_str(buf, ix);
        glk_put_string(buf);
        glk_put_char('\n');
    }
}

/* Print thirty lines in both windows. This gets fancy by printing
    to each window alternately, without setting the output stream,
    by using glk_put_string_stream() instead of glk_put_string(). 
    There's no particular difference; this is just a demonstration. */
static void verb_pageboth(winid_t win)
{
    int ix;
    winid_t otherwin;
    strid_t str, otherstr;
    char buf[32];
    
    str = glk_window_get_stream(win);
    otherwin = print_to_otherwin(win);
    if (otherwin) 
        otherstr = glk_window_get_stream(otherwin);
    else
        otherstr = NULL;

    for (ix=0; ix<30; ix++) {
        num_to_str(buf, ix);
        str_cat(buf, "\n");
        glk_put_string_stream(str, buf);
        if (otherstr)
            glk_put_string_stream(otherstr, buf);
    }
}

/* Turn on the timer. The timer prints a tick in mainwin1 every three
    seconds. */
static void verb_timer(winid_t win)
{
    glk_set_window(win);
    
    if (timer_on) {
        glk_put_string("The timer is already running.\n");
        return;
    }
    
    if (glk_gestalt(gestalt_Timer, 0) == 0) {
        glk_put_string("Your Glk library does not support timer events.\n");
        return;
    }
    
    glk_put_string("A timer starts running in the upper window.\n");
    glk_request_timer_events(3000); /* Every three seconds. */
    timer_on = TRUE;
}

/* Turn off the timer. */
static void verb_untimer(winid_t win)
{
    glk_set_window(win);
    
    if (!timer_on) {
        glk_put_string("The timer is not currently running.\n");
        return;
    }
    
    glk_put_string("The timer stops running.\n");
    glk_request_timer_events(0);
    timer_on = FALSE;
}

/* Print every character, or rather try to. */
static void verb_chars(winid_t win)
{
    int ix;
    char buf[16];
    
    glk_set_window(win);
    
    for (ix=0; ix<256; ix++) {
        num_to_str(buf, ix);
        glk_put_string(buf);
        glk_put_string(": ");
        glk_put_char(ix);
        glk_put_char('\n');
    }
}

static void verb_yada(winid_t win)
{
    /* This is a goofy (and overly ornate) way to print a long paragraph. 
        It just shows off line wrapping in the Glk implementation. */
    #define NUMWORDS (13)
    static char *wordcaplist[NUMWORDS] = {
        "Ga", "Bo", "Wa", "Mu", "Bi", "Fo", "Za", "Mo", "Ra", "Po",
            "Ha", "Ni", "Na"
    };
    static char *wordlist[NUMWORDS] = {
        "figgle", "wob", "shim", "fleb", "moobosh", "fonk", "wabble",
            "gazoon", "ting", "floo", "zonk", "loof", "lob",
    };
    static int wcount1 = 0;
    static int wcount2 = 0;
    static int wstep = 1;
    static int jx = 0;
    int ix;
    int first = TRUE;
    
    glk_set_window(win);
    
    for (ix=0; ix<85; ix++) {
        if (ix > 0) {
            glk_put_string(" ");
        }
                
        if (first) {
            glk_put_string(wordcaplist[(ix / 17) % NUMWORDS]);
            first = FALSE;
        }
        
        glk_put_string(wordlist[jx]);
        jx = (jx + wstep) % NUMWORDS;
        wcount1++;
        if (wcount1 >= NUMWORDS) {
            wcount1 = 0;
            wstep++;
            wcount2++;
            if (wcount2 >= NUMWORDS-2) {
                wcount2 = 0;
                wstep = 1;
            }
        }
        
        if ((ix % 17) == 16) {
            glk_put_string(".");
            first = TRUE;
        }
    }
    
    glk_put_char('\n');
}

static void verb_quit(winid_t win)
{
    glk_set_window(win);
    
    glk_put_string("Thanks for playing.\n");
    glk_exit();
    /* glk_exit() actually stops the process; it does not return. */
}

/* simple string length test */
static int str_len(char *s1)
{
    int len;
    for (len = 0; *s1; s1++)
        len++;
    return len;
}

/* simple string comparison test */
static int str_eq(char *s1, char *s2)
{
    for (; *s1 && *s2; s1++, s2++) {
        if (*s1 != *s2)
            return FALSE;
    }
    
    if (*s1 || *s2)
        return FALSE;
    else
        return TRUE;
}

/* simple string copy */
static char *str_cpy(char *s1, char *s2)
{
    char *orig = s1;
    
    for (; *s2; s1++, s2++)
        *s1 = *s2;
    *s1 = '\0';
    
    return orig;
}

/* simple string concatenate */
static char *str_cat(char *s1, char *s2)
{
    char *orig = s1;
    
    while (*s1)
        s1++;
    for (; *s2; s1++, s2++)
        *s1 = *s2;
    *s1 = '\0';
    
    return orig;
}

/* simple number printer */
static void num_to_str(char *buf, int num)
{
    int ix;
    int size = 0;
    char tmpc;
    
    if (num == 0) {
        str_cpy(buf, "0");
        return;
    }
    
    if (num < 0) {
        buf[0] = '-';
        buf++;
        num = -num;
    }
    
    while (num) {
        buf[size] = '0' + (num % 10);
        size++;
        num /= 10;
    }
    for (ix=0; ix<size/2; ix++) {
        tmpc = buf[ix];
        buf[ix] = buf[size-ix-1];
        buf[size-ix-1] = tmpc;
    }
    buf[size] = '\0';
}
