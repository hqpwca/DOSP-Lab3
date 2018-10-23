# Chord

## Group Member
* Ke Chen 8431-0979
* Bochen Li 4992-9405

## Usage
* First run `mix escript.build` to build the executable file
* Then just run `./chord numNodes numRequests [-f failNodes]` to run the program.

## Bonus Part
* In the bonus part, I implemented the sucessor list of each node to get failed node.
* When the percentage of the failed nodes becomes larger, the average hops per request will become larger because the some of the nodes in the finger table will be unaccessed, just as the paper says.
* Average Hops (total nodes 256):
	* 0 failed nodes -> 3.8305
	* 16 failed nodes -> 3.845
	* 64 failed nodes -> 3.89375
	* 128 failed nodes -> 4.396875
* The system is resilient most time. However, because we used less time to let the system stabilize and stop it to test, so sometimes there will be some request can't receive the correct result.

## Simulation Method
1. Implemented the chord algorithm, divided some of the function to prevent the usage of the `call` in `GenServer`. In this way, we can let elixir itself to deal with the concurrency problems rather than having program stucked because of deadlock.)

2. Each node periodically runs `stabilize` and `fix_finger` function to get the right value of the successor and finger table. The `stabilize` will call `notify` to update the predecessor of the nodes. The time between 2 updates is decided by the total number of nodes.

3. The hash value of each node and message is the first 32 bits of the MD5 cryption. So the size of the chord circle is 2^32. (hash value of node i is from the MD5 of string "node[i]"(without the parenthesis), and hash value of message i is from the MD5 of string "message[i]")

4. The joins of each node has some time intervals between. The interval is about 4 times the node update interval. This can let the node at least get correct predecessor and successor, which can get the chord circle stabilize much more rapidly. 

5. After the join, the program will sleep for a short period of time to wait for the nodes to stabilize.**This will lead to the result that the time for join is in proportion to the square of the numNodes.**

6. Each node will send a request every second. The message pool which can be chosen by nodes haven't been implemented, but requesting the same message can also get reasonable answer.

7. The successor of each message is precalculated before the whole simulation. After a node received the result of a request, it will send it to the collector to check its correctness. If the num of the nodes is too large, the first several generation of requests may get wrong result, but it will soon stabilize.

8. The average hops is calculated by the collector. Every time a node is accessed because of message request, it will add the `total_hops` by 1, the average hops is calculated by `total_hops/total_requests = total_hops/numNodes/numRequests`.

## Largest Network

* After changing some parameters in the program, with 5 times the joining time to stabilize, I can run network with nodes as much as 10000, but this will take a pretty long time to join all the nodes and wait it to stabilize(about 4 hours) 

* The parameters set now can run nodes as much as 500 smoothly, which will not get an error in the first generation. When the num of the nodes comes to 1000, the first several generations will get a few wrong result, but this will soon disappear after 3-4 generations.

* The num of the requests are unlimited, for it will take less than a second to get all the result of all the requests. Nothing will go bad if the num of the requests increases.



