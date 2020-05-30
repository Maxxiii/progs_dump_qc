
/* ============================================ */
/* |        Movie camera trigger  - dhm       | */
/* ============================================ */


void(entity o) spawn_dummy =
{
local entity	s;

	s = spawn ();
	s.origin = o.origin;
	s.velocity = o.velocity;
	s.angles = o.angles;
	s.health = o.health;
	s.weapon = o.weapon;
	s.classname = "dummy";
	s.movetype = MOVETYPE_NONE;
	s.solid = SOLID_NOT;
	s.weaponmodel = o.weaponmodel;
	s.flags = o.flags;
	setorigin (s, o.origin);
};

void() name_player =
{
local entity play;

	play = find(world, classname, "camera");
	play.classname = "player";
	stuffcmd(play, "-forward\n");
};

void() go_back =
{
local entity	t,c,d;
// local vector	org; hostage meat stuff not needed
local string	val;
local string	val2; //dumptruck_ds

	t = find (world, classname, "dummy");
	if (!t)
		objerror ("couldn't find dummy");

	c = find (world, classname, "camera");
	if (!c)
		objerror ("couldn't find camera");

	setorigin (c, t.origin);
	c.velocity = t.velocity;
	c.view_ofs = '0 0 22';
	c.angles_x = t.angles_x;
	c.angles_y = t.angles_y;
	c.angles_z = 0;
	c.health = t.health;
	c.weapon = t.weapon;
	c.weaponmodel = t.weaponmodel;
	c.flags = t.flags;
	c.fixangle = 1;		// turn this way immediately
	c.takedamage = DAMAGE_AIM;
	c.solid = SOLID_SLIDEBOX;
	c.movetype = MOVETYPE_WALK;
	c.think = SUB_Null;
	c.air_finished = time + 12;  // No gasping from you!

/* If you change the classname during this frame, then the
   'find' command ABOVE will fail, so set a timer to change
   the classname back to player.  [grrrrr, I spent way too
   long figuring that out.] */
	d = spawn();
	d.nextthink = time + 0.1;
	d.think = name_player;

	val = ftos (c.cnt);
	val2 = ftos (c.dmg); // dumptruck_ds
	cvar_set ("viewsize", val);  	//restore old viewsize
	cvar_set ("sensitivity", val2);  	//restore old mouse sensitivity hack for QS stuttering - dumptruck_ds
	cvar_set ("v_idlescale", "0");  //stop the swaying camera


	t.nextthink = time + 0.1;
	t.think = SUB_Remove;
	remove(self);
};

/* This routine short-circuits player turning movement while
     in camera mode.
*/
void() look_ahead =
{
	self.angles = self.enemy.mangle;
	self.fixangle = 1;
	self.nextthink = time + 0.01;
};

void() go_camera =
{
// Change the player into a camera
	self.classname = "camera";
	self.velocity = '0 0 0';
	self.view_ofs = '0 0 0';
	self.angles = self.enemy.mangle;
	self.fixangle = 1;		// turn this way immediately
	self.movetype = MOVETYPE_NONE;
	self.takedamage = DAMAGE_NO;
	self.solid = SOLID_NOT;
	self.weaponmodel = "";

// Keep player looking straight ahead
	self.nextthink = time + 0.05;
	self.think = look_ahead;

//Setting script_count to 0 is what triggers the script to play,
//  It will then play the script number.
	if (!self.script)
		dprint ("trigger_camera needs a script number");
	self.script_count = 0;

//Save current viewscreen size to return to after camera.
	self.cnt = cvar("viewsize");
	self.dmg = cvar("sensitivity"); //save the mouse sensitivity for later - dumptruck_ds
	cvar_set ("viewsize", "120");	 //Full screen
	cvar_set ("v_idlescale", "1");  //Swaying camera
	cvar_set ("sensitivity", "0");  //no mouse for you! fix for Quakespasm stuttering while player is camera - dumptruck_ds

	setorigin (self, self.enemy.origin);
};

void() camera_touch =
{
local entity	t;

	if (self.targetname)
	{
		if (self.nextthink < time)
		{
			return;		// not fired yet
		}
	}

// only activate for player
	if (other.health <= 0 || other.classname != "player" || self.cnt == -1)
		return;

	SUB_UseTargets ();

//If player is on ground, take him off ground so no one gets confused
	if (other.flags & FL_ONGROUND)
	    other.flags = other.flags - FL_ONGROUND;

// put a dummy where the player was
	spawn_dummy (other);

// find camera
	t = find (world, targetname, self.target);
	if (!t)
		objerror ("couldn't find target");

// Go to the camera - not in this function, because touch functions are
// called while looping through c code, and you don't want to move the
// player, or something like that?
	other.enemy = t;		//save camera position, etc.
	other.script = self.script;	//save script number
	other.script_delay = self.script_delay;  //save delay for page 1
	other.nextthink = time + 0.05;
	other.think = go_camera;

	self.cnt = -1;  //used to make sure only one dummy is spawned;

//Remove the trigger_camera from level
	self.nextthink = time + 0.1;
	self.think = SUB_Remove;
};

/*QUAKED info_movie_camera (.5 .5 .5) (-8 -8 -8) (8 8 32)
This is the destination marker for a camera.  It should have a "targetname"
field with the same value as a camera-trigger's "target" field.  The "mangle"
controls the view just like a info_intermission(pitch roll yaw).
*/
void() info_movie_camera =
{
// this does nothing, just serves as a target spot
if (SUB_Inhibit ())  // new spawnflags for all entities -- iw
	return;
};

void() camera_use =
{
	self.nextthink = time + 100000;
	force_retouch = 2;		// make sure even still objects get hit
	self.think = SUB_Null;
};

/*QUAKED trigger_camera (.5 .5 .5) ?
A player touching this will be transported to the corresponding
info_movie_camera entity. You must set the "target" field, and put a
info_movie_camera with a "targetname" field that matches.  The "script" key
gives a starting script number, and the "script_delay" key is the amount of
time(seconds) to stay on the first script page.

If the trigger_camera has a targetname, it will only enter camera mode after it
has been fired.
*/
void() trigger_camera =
{
	if (SUB_Inhibit ())  // new spawnflags for all entities -- iw
		return;

	if (deathmatch || coop)
		remove (self);

	InitTrigger ();
	self.touch = camera_touch;
	// find the destination
	if (!self.target)
		objerror ("no target");
	self.use = camera_use;
};


/* ----------------------------------
  	   Scripting function - dhm
   ---------------------------------- */
/* The original timing idea for scripts was inspired by
	Zoid.  Study the code for Zoid's CTF, it is an
	excellent example of good Quake-C coding.  Also
	look at all of Quake Command's stuff.  Wedge rules.
*/

void() Script_play =
{
local entity	scrpt;

	scrpt = find (world, script_num, self.script);
	if (!scrpt)
	   dprint ("Error: script not found!");

	self.script_delay = scrpt.script_delay;
	self.script_time = time + 1;
	self.script_count = self.script_count + 1;
	centerprint(self, scrpt.message);

	if (self.script_count == self.script_delay)
	{
	   self.script = scrpt.next_script;
	   if (self.script != "0")
	       self.script_count = 0;
	   else
	     {
		 scrpt.nextthink = time + 4;
		 scrpt.think = go_back;
	     }
	}
	return;
};


/*QUAKED info_script (.5 .5 .5) (-8 -8 -8) (8 8 32)
This is the destination marker for a script.
It should have a "script_num" field that signifies the script number, and a
"next_script" to signal the next script ("0" if this is the last page of the
script), a "script_delay" to signify how many seconds to display this page, and
of course a "message" field with the text to display.
*/
void() info_script =
{
	if (SUB_Inhibit ())  // new spawnflags for all entities -- iw
		return;
};



// /* ---------------------------------- */
// /* |      Meat decoration item      | */
// /* ---------------------------------- */
//
// /*QUAKED misc_meat (.5 .5 .5) (-8 -8 -8) (8 8 32)
// This is a decorative pile of rotting meat/gibs.  Dogs will stop what they are doing to enjoy this tasty meal.  Good for ambience.
// */
//
// void() meat_pain =
// {
// 	self.health = 1000000;
// };
//
// void() misc_meat =
// {
// 	if (SUB_Inhibit ())  // new spawnflags for all entities -- iw
// 		return;
//
// local entity	meat1,meat2,meat3,meathead;
// local vector	org;
//
// 	meat1 = spawn ();
// 	meat1.owner = self;
// 	meat1.movetype = MOVETYPE_BOUNCE;
// 	meat1.solid = SOLID_BBOX;
// 	meat1.takedamage = DAMAGE_AIM;
// 	meat1.touch = SUB_Null;
// 	meat1.velocity_z = 50 * random();
// 	meat1.avelocity = '100 300 200';
// 	org = self.origin + '20 5 5';
// 	meat1.classname = "gib";
// 	meat1.think = SUB_Null;
// 	meat1.health = 100000;
// 	meat1.th_pain = meat_pain;
// 	meat1.th_die = meat_pain;
// 	setmodel (meat1, "progs/gib3.mdl");
// 	setsize (meat1, '0 0 0', '0 0 0');
// 	setorigin (meat1, org);
//
// 	meat2 = spawn ();
// 	meat2.owner = self;
// 	meat2.movetype = MOVETYPE_BOUNCE;
// 	meat2.solid = SOLID_BBOX;
// 	meat2.takedamage = DAMAGE_AIM;
// 	meat2.touch = SUB_Null;
// 	meat2.velocity_z = 50 * random();
// 	meat2.avelocity = '200 100 300';
// 	org = self.origin + '10 20 5';
// 	meat2.classname = "gib";
// 	meat2.health = 100000;
// 	meat2.th_pain = meat_pain;
// 	meat2.th_die = meat_pain;
// 	meat2.think = SUB_Null;
// 	setmodel (meat2, "progs/gib2.mdl");
// 	setsize (meat2, '0 0 0', '0 0 0');
// 	setorigin (meat2, org);
//
// 	meat3 = spawn ();
// 	meat3.owner = self;
// 	meat3.movetype = MOVETYPE_BOUNCE;
// 	meat3.solid = SOLID_BBOX;
// 	meat3.takedamage = DAMAGE_AIM;
// 	meat3.touch = SUB_Null;
// 	meat3.velocity_z = 50 * random();
// 	meat3.avelocity = '500 10 200';
// 	org = self.origin + '-10 -20 5';
// 	meat3.classname = "gib";
// 	meat3.health = 100000;
// 	meat3.th_pain = meat_pain;
// 	meat3.th_die = meat_pain;
// 	meat3.think = SUB_Null;
// 	setmodel (meat3, "progs/gib2.mdl");
// 	setsize (meat3, '0 0 0', '0 0 0');
// 	setorigin (meat3, org);
//
// 	meathead = spawn ();
// 	meathead.owner = self;
// 	meathead.movetype = MOVETYPE_BOUNCE;
// 	meathead.solid = SOLID_BBOX;
// 	meathead.takedamage = DAMAGE_AIM;
// 	meathead.touch = SUB_Null;
// 	meathead.velocity_z = 50 * random();
// 	meathead.avelocity = '150 350 225';
// 	org = self.origin + '2 2 5';
// 	meathead.classname = "meat";
// 	meathead.health = 100000;
// 	meathead.th_pain = meat_pain;
// 	meathead.th_die = meat_pain;
// 	meathead.think = SUB_Null;
// 	setmodel (meathead, "progs/h_player.mdl");
// 	setsize (meathead, '-16 -16 0', '16 16 26');
// 	setorigin (meathead, org);
// };

//
// /* ---------------------------- */
// /* |  A soldier held hostage  | */
// /* ---------------------------- */
// /*  I should have done a better job with the hostages, but
//     time was short.  It would have been nice to make it so
//     that a spawnflag on the monsters would determine if they
//     would attack the hostages.  Oh well, shamblers make good
//     executioners.
// */
//
// void() hostage_pain =
// {
// local float 	r;
//
// 	r = random();
//
// 	if (r < 0.1)
// 	    bprint("Hostage: Aaargh!!\n");
// 	if (r > 0.9)
// 	    bprint("Hostage: Uuogggghh! Help!\n");
//
// 	self.ideal_yaw = vectoyaw(self.enemy.origin - self.origin);
// 	ChangeYaw();
// 	ai_back(5);
// 	player_pain1 ();
// };
//
// /* The wacky stuff in this procedure is to get the shambler to
// 	run around after killing the hostages.
// */
// void() HostageDie =
// {
// local entity 	sham,olde;
//
// 	sham = find(world, classname, "monster_shambler");
// 	olde = find(world, netname, "hostage");
//
// 	if(olde.health < 0)
// 	{
// 		olde = find(world, netname, "hostage");
// 		if (olde.health < 0)
// 	  	{
// 			olde = find(world, classname, "camera");
// 			sham.oldenemy = olde;
// 		}
// 	}
// 	else sham.oldenemy = olde;
//
// 	self.health = -80;
// 	PlayerDie();
// };
//
// /*QUAKED misc_hostage (.5 .5 .5) (-8 -8 -8) (8 8 32)
// This is a player character that will just stand there forever.
// The hostage reacts to pain just as a player, and will die.
// The hostage will sometimes yell for help when in pain.
// Only shambler's attack the hostages.
// */
// void() misc_hostage =
// {
// 	if (SUB_Inhibit ())  // new spawnflags for all entities -- iw
// 		return;
//
// local entity	body;
//
// 	makevectors (self.angles);
// 	body = spawn();
// 	setmodel (body, "progs/player.mdl");
// 	setsize (body, VEC_HULL_MIN, VEC_HULL_MAX);
// 	body.origin = self.origin + '0 0 1';
// 	setorigin (body, body.origin);
// 	body.classname = "player";
// 	body.netname = "hostage";
// 	body.health = 150;
// 	body.takedamage = DAMAGE_AIM;
// 	body.solid = SOLID_SLIDEBOX;
// 	body.movetype = MOVETYPE_STEP;    // They just stand on the ground
// 	body.show_hostile = 0;
// 	body.weapon = IT_SHOTGUN;
//       body.weaponframe = 0;
// 	body.walkframe = 0;
// 	body.frame = 12;
// 	body.th_pain = hostage_pain;
// 	body.th_die = HostageDie;
// 	body.th_stand = player_stand1;
// 	self = body;
// 	self.enemy = find(world, classname, "monster_shambler");
// 	self.yaw_speed = 30;
// 	droptofloor();
// 	player_stand1 ();
// };
//
//
// /******************************************/
// /* -------------------------------------
//    |   Finale sequence     -  dhm      |
//    | 						   |
//    | These functions are only really   |
//    | valid for my level.               |
//    -------------------------------------  */
// /******************************************/
//
// void() warning_stop =
// {
// 	self.cnt = -1;
// 	self.think = SUB_Remove;
// };
//
// void(entity play) warn_player =
// {
// 	if(play.view_ofs == '0 0 0')
// 		return;
//
// 	stuffcmd(play, "bf\n");
// 	sound(play, CHAN_AUTO, "items/inv2.wav", 1, ATTN_NORM);
// 	centerprint(play, "Reactor Overload!\nEvacuate Immediately\n");
// 	T_Damage(play, world, world, self.cnt);
// };
//
// void() warning_start =
// {
// local entity	you;
//
// 	you = find(world, classname, "player");
// 	if(!you)
// 		return;
// 	if(you.view_ofs == '0 0 0')
// 		return;
// 	if(self.cnt > 0)
// 	{
// 		warn_player(you);
// 		self.cnt = self.cnt + 1;
// 		self.nextthink = time + 4;
// 		self.think = warning_start;
// 	}
// 	else remove(self);
// };
//
// void() warning_touch =
// {
// 	if(other.health <= 0 || other.classname != "player")
// 		return;
//
// 	self.solid = SOLID_NOT;
// 	self.nextthink = time + 2;
// 	self.think = warning_start;
// };
//
// /*QUAKED overload_warning (.5 .5 .5) (-8 -8 -8) (8 8 32)
// Item used to start the warning flashes and messages
// */
// void() overload_warning =
// {
// 	precache_sound ("items/inv2.wav");
//
// 	self.cnt = 1;
// 	self.use = warning_stop;
// 	self.touch = warning_touch;
// 	self.model = string_null;
// 	setsize (self, '0 0 0', '32 32 56');
// 	StartItem ();
// };
//
// void() big_bang =
// {
// 	local	vector	newo;
// 	local	float	x, y, z;
//
// 	if (self.wait == 1)
// 		sound (self, CHAN_VOICE, "boss2/pop2.wav", 1, ATTN_NONE);
//
// 	x = (random() * 128) - 64;
// 	y = (random() * 128) - 64;
// 	z = (random() * 128) - 64;
//
// 	newo_x = self.origin_x + x;
// 	newo_y = self.origin_y + y;
// 	newo_z = self.origin_z + z;
//
// 	WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
// 	WriteByte (MSG_BROADCAST, TE_EXPLOSION);
// 	WriteCoord (MSG_BROADCAST, newo_x);
// 	WriteCoord (MSG_BROADCAST, newo_y);
// 	WriteCoord (MSG_BROADCAST, newo_z);
//
// 	self.wait = self.wait - 1;
// 	if(self.wait < 0)
// 		remove(self);
//
// 	self.nextthink = time + (0.2 * random()) + 0.1;
// 	self.think = big_bang;
// };
//
// /*QUAKED misc_kaboom (.5 .5 .5) (-8 -8 -8) (8 8 32)
// This starts a sphere of explosions when triggered.
// The "wait" field is the number of explosions you want.
// */
// void() misc_kaboom =
// {
// 	precache_sound2 ("boss2/pop2.wav");
//
// 	self.use = big_bang;
// };
//
// /*QUAKED lava_splash (.5 .5 .5) (-8 -8 -8) (8 8 32)
// Placeholders for my lava splashes.
// */
// void() lava_splash =
// {
// };
//
// void() fade_away =
// {
// 	if(self.cnt == 12)
// 		lightstyle(0, "l");
// 	else if(self.cnt == 11)
// 		lightstyle(0, "k");
// 	else if(self.cnt == 10)
// 		lightstyle(0, "j");
// 	else if(self.cnt == 9)
// 		lightstyle(0, "i");
// 	else if(self.cnt == 8)
// 		lightstyle(0, "h");
// 	else if(self.cnt == 7)
// 		lightstyle(0, "g");
// 	else if(self.cnt == 6)
// 		lightstyle(0, "f");
// 	else if(self.cnt == 5)
// 		lightstyle(0, "e");
// 	else if(self.cnt == 4)
// 		lightstyle(0, "d");
// 	else if(self.cnt == 3)
// 		lightstyle(0, "c");
// 	else if(self.cnt == 2)
// 		lightstyle(0, "b");
// 	else if(self.cnt == 1)
// 	{
// 		lightstyle(0, "a");
// 		return;
// 	}
// 	self.cnt = self.cnt - 1;
// 	self.think = fade_away;
// 	self.nextthink = time + 0.5;
// };
//
// void() finale_touch =
// {
// local entity	ls,dim;
//
// 	if(other.health <= 0 || other.classname != "player" || self.cnt == -1)
// 		return;
//
// 	ls = find(world, classname, "lava_splash");
// 	while (ls)
// 	{
// 		WriteByte (MSG_BROADCAST, SVC_TEMPENTITY);
// 		WriteByte (MSG_BROADCAST, TE_LAVASPLASH);
// 		WriteCoord (MSG_BROADCAST, ls.origin_x);
// 		WriteCoord (MSG_BROADCAST, ls.origin_y);
// 		WriteCoord (MSG_BROADCAST, ls.origin_z);
// 		remove(ls);
// 		ls = find(world, classname, "lava_splash");
// 	}
// 	sound (self, CHAN_VOICE, "boss1/out1.wav", 1, ATTN_NONE);
//
// 	dim = spawn();
// 	dim.cnt = 12;
// 	dim.nextthink = time + 13;
// 	dim.think = fade_away;
//
// 	self.think = SUB_UseTargets;
// 	self.nextthink = time + 4;
// 	self.cnt = -1;
// };
//
// /*QUAKED trigger_finale (.5 .5 .5) (-8 -8 -8) (8 8 32)
// This triggers the start of my finale sequence.
// */
// void() trigger_finale =
// {
// 	if (deathmatch || coop)
// 		remove (self);
//
// 	precache_sound ("boss1/out1.wav");
// 	InitTrigger ();
// 	self.touch = finale_touch;
// 	// find the destination
// 	if (!self.target)
// 		objerror ("no target");
// };
