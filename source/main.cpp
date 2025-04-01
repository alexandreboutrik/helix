#include <raylib.h>

#include <iostream>

int
main(void)
{
    InitWindow(900, 900, "TEST");
    SetTargetFPS(60);

    while (! WindowShouldClose())
    {
        BeginDrawing();

        ClearBackground(BLUE);
        DrawRectangle(20, 20, 60, 60, RED);

        EndDrawing();
    }

    CloseWindow();

    return 0;
}
